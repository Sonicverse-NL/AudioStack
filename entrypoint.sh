#!/bin/sh
set -e

# Function to update a tag in the Icecast XML configuration
xml_edit() {
    local tag="$1"
    local value="$2"
    local file="$3"

    if ! grep -q "<${tag}>" "$file"; then
        echo "Warning: Tag <${tag}> not found in $file" >&2
        return 1
    fi
    sed -i "s|<${tag}>.*</${tag}>|<${tag}>${value}</${tag}>|g" "$file"
}

# Function to apply configuration to the main icecast.xml
edit_icecast_config() {
    xml_edit "$@" "/etc/icecast2/icecast.xml"
}

# Function to kill any process listening on a given port
kill_process_on_port() {
    local port="$1"
    echo "Checking for processes on port ${port}..."
    local pid=$(netstat -tulpn | grep ":${port} " | awk '{print $7}' | cut -d'/' -f1)
    if [ -n "$pid" ]; then
        echo "Process with PID $pid found on port ${port}. Killing it..."
        kill -9 "$pid"
        sleep 2 # Give it a moment to die
    else
        echo "Port ${port} is free."
    fi
}

# Set default ports if not provided
ICECAST_PORT=${ICECAST_PORT:-3000}
LIQUIDSOAP_HARBOR_PORT_1=${LIQUIDSOAP_HARBOR_PORT_1:-8001}
LIQUIDSOAP_HARBOR_PORT_2=${LIQUIDSOAP_HARBOR_PORT_2:-8002}

# Generate a random source password if not set
if [ -z "$ICECAST_SOURCE_PASSWORD" ]; then
    ICECAST_SOURCE_PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)
fi
export ICECAST_SOURCE_PASSWORD

# Generate random passwords for harbor inputs if not set
if [ -z "$INPUT_1_PASSWORD" ]; then
    INPUT_1_PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)
fi
if [ -z "$INPUT_2_PASSWORD" ]; then
    INPUT_2_PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)
fi

# Configure Icecast
echo "Configuring Icecast..."
edit_icecast_config source-password "$ICECAST_SOURCE_PASSWORD"
edit_icecast_config relay-password "$ICECAST_SOURCE_PASSWORD"
edit_icecast_config admin-password "${ICECAST_ADMIN_PASSWORD:-hackme}"
edit_icecast_config admin-user "${ICECAST_ADMIN_USERNAME:-admin}"
edit_icecast_config admin "${ICECAST_ADMIN_EMAIL:-admin@localhost}"
edit_icecast_config location "${ICECAST_LOCATION:-Earth}"
edit_icecast_config hostname "${ICECAST_HOSTNAME:-localhost}"
edit_icecast_config clients "${ICECAST_MAX_CLIENTS:-100}"
edit_icecast_config sources "${ICECAST_MAX_SOURCES:-10}"
edit_icecast_config port "$ICECAST_PORT"

# Set icecast to run as icecast user
if grep -q "<changeowner>" /etc/icecast2/icecast.xml; then
    edit_icecast_config user "icecast"
    edit_icecast_config group "icecast"
fi

# Function to generate the Liquidsoap configuration
edit_liquidsoap_config() {
    echo "Generating Liquidsoap configuration..."
    cat <<EOF > "/etc/liquidsoap/config.liq"
# Logging
def log_event(input_name, event) = log("#{input_name} #{event}", level=3) end

# Fallback emergency file
emergency = single("/etc/liquidsoap/emergency.wav")

# Harbor inputs for the two studio streams
raw_studio_a = input.harbor("/studio_a", port=${LIQUIDSOAP_HARBOR_PORT_1}, password="${INPUT_1_PASSWORD}", icy=true)
raw_studio_b = input.harbor("/studio_b", port=${LIQUIDSOAP_HARBOR_PORT_2}, password="${INPUT_2_PASSWORD}", icy=true)

# Add silence detection to log events
detected_studio_a = blank.detect(id="detect_studio_a", max_blank=15., fun() -> log_event("studio_a", "silence detected"), on_noise=fun() -> log_event("studio_a", "audio resumed"), raw_studio_a)
detected_studio_b = blank.detect(id="detect_studio_b", max_blank=15., fun() -> log_event("studio_b", "silence detected"), on_noise=fun() -> log_event("studio_b", "audio resumed"), raw_studio_b)

# Strip silence to make inputs unavailable during silence
stripped_studio_a = blank.strip(id="stripped_studio_a", max_blank=15., detected_studio_a)
stripped_studio_b = blank.strip(id="stripped_studio_b", max_blank=15., detected_studio_b)

# Buffer inputs to prevent disconnections from affecting the stream
studio_a = buffer(id="buffered_studio_a", fallible=true, stripped_studio_a)
studio_b = buffer(id="buffered_studio_b", fallible=true, stripped_studio_b)

# Fallback logic: studio_a -> studio_b -> emergency
radio = fallback(id="radio_prod", track_sensitive=false, [studio_a, studio_b, emergency])

# Create a clock for the output
audio_to_icecast = mksafe(buffer(radio))
clock.assign_new(id="icecast_clock", [audio_to_icecast])

# Function to create an Icecast output stream
def output_icecast_stream(~format, ~mount, ~source) =
  output.icecast(
    format,
    fallible=false,
    host="localhost",
    port=${ICECAST_PORT},
    password="${ICECAST_SOURCE_PASSWORD}",
    name="${STATION_NAME:-AudioStack}",
    description="${STATION_DESCRIPTION:-A robust audio streaming server}",
    genre="${STATION_GENRE:-Various}",
    url="${STATION_URL:-http://localhost}",
    public=true,
    mount=mount,
    source
  )
end

# High and low bitrate MP3 streams
output_icecast_stream(format=%mp3(bitrate=192, samplerate=48000), mount="/radio", source=audio_to_icecast)
output_icecast_stream(format=%mp3(bitrate=96, samplerate=48000), mount="/radio-lq", source=audio_to_icecast)
EOF
}

# Function to create a silent emergency file
create_silence_fallback() {
    echo "Creating 120-second silent WAV file as emergency fallback..."
    ffmpeg -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 -t 120 -acodec pcm_s16le /etc/liquidsoap/emergency.wav -y >/dev/null 2>&1
    if [ $? -eq 0 ] && [ -s /etc/liquidsoap/emergency.wav ]; then
        echo "Silence file created successfully."
    else
        echo "Error: Failed to create silence file." >&2
        exit 1
    fi
}

# Prepare emergency file
if [ -n "$EMERGENCY_URL" ]; then
    echo "Downloading emergency file from $EMERGENCY_URL..."
    if ! curl -fsSL -o /etc/liquidsoap/emergency.wav "$EMERGENCY_URL" || [ ! -s /etc/liquidsoap/emergency.wav ]; then
        echo "Warning: Download failed or file is empty. Creating silent fallback."
        create_silence_fallback
    else
        echo "Emergency file downloaded successfully."
    fi
else
    create_silence_fallback
fi

# Generate Liquidsoap config
edit_liquidsoap_config

# Check and clear ports before starting services
kill_process_on_port "$ICECAST_PORT"
kill_process_on_port "$LIQUIDSOAP_HARBOR_PORT_1"
kill_process_on_port "$LIQUIDSOAP_HARBOR_PORT_2"

# Start Icecast in the background as the icecast user
echo "Starting Icecast..."
su -s /bin/sh -c "icecast2 -c /etc/icecast2/icecast.xml" icecast &

# Wait for Icecast to start
echo "Waiting for Icecast to be ready..."
for i in $(seq 1 10); do
    if netstat -tulpn | grep -q ":${ICECAST_PORT} "; then
        echo "Icecast is up and running."
        break
    fi
    echo "Waiting... ($i/10)"
    sleep 1
done

if ! netstat -tulpn | grep -q ":${ICECAST_PORT} "; then
    echo "Error: Icecast failed to start. Check /var/log/icecast2/error.log" >&2
    exit 1
fi

# Start Liquidsoap in the foreground as the icecast user
echo "Starting Liquidsoap..."
su -s /bin/sh -c "liquidsoap /etc/liquidsoap/config.liq" icecast