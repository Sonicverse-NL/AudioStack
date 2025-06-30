#!/bin/sh
xml_edit() {
  local tag="$1"
  local value="$2"
  local file="$3"

  # Check if the tag exists in the XML file
  if ! grep -q "<${tag}>" "$file"; then
    echo "Tag <${tag}> not found in $file" >&2
    return 1
  fi

  # Update the value of the tag in the XML file
  sed -i "s|<${tag}>.*</${tag}>|<${tag}>${value}</${tag}>|g" "$file"
}


# Dynamically update configuration from environment variables
edit_icecast_config() {
  xml_edit "$@" /etc/icecast2/icecast.xml
}

# Generate a random password if ICECAST_SOURCE_PASSWORD is not set
if [ -z "$ICECAST_SOURCE_PASSWORD" ]; then
    ICECAST_SOURCE_PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)
    export ICECAST_SOURCE_PASSWORD
fi

# Set SOURCE_PASSWORD for Liquidsoap if not already set
SOURCE_PASSWORD="$ICECAST_SOURCE_PASSWORD"
export SOURCE_PASSWORD




edit_icecast_config source-password "$ICECAST_SOURCE_PASSWORD"
edit_icecast_config relay-password "$ICECAST_SOURCE_PASSWORD"


if [ -n "$ICECAST_ADMIN_PASSWORD" ]; then
  edit_icecast_config admin-password "$ICECAST_ADMIN_PASSWORD"
fi
if [ -n "$ICECAST_ADMIN_USERNAME" ]; then
  edit_icecast_config admin-user "$ICECAST_ADMIN_USERNAME"
fi
if [ -n "$ICECAST_ADMIN_EMAIL" ]; then
  edit_icecast_config admin "$ICECAST_ADMIN_EMAIL"
fi
if [ -n "$ICECAST_LOCATION" ]; then
  edit_icecast_config location "$ICECAST_LOCATION"
fi
if [ -n "$ICECAST_HOSTNAME" ]; then
  edit_icecast_config hostname "$ICECAST_HOSTNAME"
fi
if [ -n "$ICECAST_MAX_CLIENTS" ]; then
  edit_icecast_config clients "$ICECAST_MAX_CLIENTS"
fi
if [ -n "$ICECAST_MAX_SOURCES" ]; then
  edit_icecast_config sources "$ICECAST_MAX_SOURCES"
fi

# Set icecast to run as icecast user (security requirement)
# Note: These tags might not exist in default config, but we'll try to add them
if grep -q "<changeowner>" /etc/icecast2/icecast.xml; then
  edit_icecast_config changeowner-user "icecast"
  edit_icecast_config changeowner-group "icecast"
else
  echo "Warning: changeowner tags not found in icecast.xml - will run as root"
fi

# Generates the Liquidsoap configuration file at /etc/liquidsoap/config.liq
# using environment variables for stream passwords and metadata.
# Call this function to update the Liquidsoap config before starting the service.
edit_liquidsoap_config() {
  cat <<EOF > "/etc/liquidsoap/config.liq"
# Logging function for various events
def log_event(input_name, event) =
  log(
    "#{input_name} #{event}",
    level=3
  )
end


# Backup file to be played when no audio is coming from the studio
noodband = single("/etc/liquidsoap/noodband.wav")

# Input for primary studio stream
studio_a =
  input.harbor(
    "/",
    port=8001,
    password="${INPUT_1_PASSWORD}"
  )

# Input for backup studio stream
studio_b =
  input.harbor(
    "/",
    port=8002,
    password="${INPUT_2_PASSWORD}"
  )

# Log silence detection and resumption
studio_a =
  blank.detect(
    id="detect_studio_a",
    max_blank=15.0,
    min_noise=15.0,
    fun () ->
      log_event(
        "studio_a",
        "silence detected"
      ),
    on_noise=
      fun () ->
        log_event(
          "studio_a",
          "audio resumed"
        ),
    studio_a
  )

studio_b =
  blank.detect(
    id="detect_studio_b",
    max_blank=15.0,
    min_noise=15.0,
    fun () ->
      log_event(
        "studio_b",
        "silence detected"
      ),
    on_noise=
      fun () ->
        log_event(
          "studio_b",
          "audio resumed"
        ),
    studio_b
  )

# Consider inputs unavailable when silent
studio_a =
  blank.strip(id="stripped_studio_a", max_blank=15., min_noise=15., studio_a)
studio_b =
  blank.strip(id="stripped_studio_b", max_blank=15., min_noise=15., studio_b)

# Wrap it in a buffer to prevent latency from connection/disconnection to impact downstream operators/output
studio_a = buffer(id="buffered_studio_a", fallible=true, studio_a)
studio_b = buffer(id="buffered_studio_b", fallible=true, studio_b)

# Combine live inputs and fallback
radio =
  fallback(
    id="radio_prod", track_sensitive=false, [studio_a, studio_b, noodband]
  )

# Process the radio stream
radioproc = radio

# Create a clock for output to Icecast
audio_to_icecast = mksafe(buffer(radioproc))
clock.assign_new(id="icecast_clock", [audio_to_icecast])

# Function to output an icecast stream with common parameters
def output_icecast_stream(~format, ~mount, ~source) =
  output.icecast(
    format,
    fallible=false,
    host="localhost",
    port=8000,
    password="${SOURCE_PASSWORD}",
    name="${STATION_NAME}",
    description="${STATION_DESCRIPTION}",
    genre="${STATION_GENRE}",
    url="${STATION_URL}",
    public=true,
    mount=mount,
    source
  )
end

# Output a high bitrate mp3 stream
output_icecast_stream(
  format=%mp3(bitrate = 192, samplerate = 48000, internal_quality = 0),
  mount="/radio.mp3",
  source=audio_to_icecast
)

# Output a low bitrate stream (fallback to MP3 if AAC not available)
output_icecast_stream(
  format=%mp3(bitrate = 96, samplerate = 48000),
  mount="/radio-lq.mp3",
  source=audio_to_icecast
)
EOF
}

download_noodband() {
    echo "Downloading noodband.wav from FTP server..."
    if curl --ftp-pasv -u "$NOODBAND_USER:$NOODBAND_PASS" -o /etc/liquidsoap/noodband.wav "$NOODBAND_URL"; then
        # Check if the downloaded file is a valid audio file (more than 100 bytes)
        if [ -f /etc/liquidsoap/noodband.wav ] && [ $(stat -c%s /etc/liquidsoap/noodband.wav) -gt 100 ]; then
            echo "Noodband file downloaded successfully"
            return 0
        else
            echo "Downloaded file is too small or invalid"
            rm -f /etc/liquidsoap/noodband.wav
            return 1
        fi
    else
        echo "FTP download failed"
        return 1
    fi
}

# Function to create a silence fallback file
create_silence_fallback() {
    echo "Creating 10-second silence file as noodband.wav..."
    ffmpeg -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 -t 10 -acodec pcm_s16le /etc/liquidsoap/noodband.wav -y 2>/dev/null || {
        echo "Error: Could not create noodband.wav with ffmpeg, trying alternative method..."
        # Alternative method using sox if available, or create a minimal valid WAV
        if command -v sox >/dev/null 2>&1; then
            sox -n -r 48000 -c 2 /etc/liquidsoap/noodband.wav trim 0.0 10.0
        else
            echo "Error: Could not create noodband.wav fallback"
            exit 1
        fi
    }
    
    # Verify the created file
    if [ -f /etc/liquidsoap/noodband.wav ] && [ $(stat -c%s /etc/liquidsoap/noodband.wav) -gt 1000 ]; then
        echo "Silence fallback created successfully"
    else
        echo "Error: Failed to create valid noodband.wav file"
        exit 1
    fi
}

# Generate Liquidsoap configuration
echo "Generating Liquidsoap configuration..."
echo "Using SOURCE_PASSWORD: $SOURCE_PASSWORD"
echo "Using ICECAST_SOURCE_PASSWORD: $ICECAST_SOURCE_PASSWORD"
edit_liquidsoap_config

# Download noodband file if FTP credentials are provided
if [ -n "$NOODBAND_URL" ] && [ -n "$NOODBAND_USER" ] && [ -n "$NOODBAND_PASS" ]; then
    if ! download_noodband; then
        echo "Warning: Noodband download failed, creating silence fallback..."
        create_silence_fallback
    fi
else
    echo "No noodband FTP configuration provided, creating silence fallback..."
    create_silence_fallback
fi

exec "$@"