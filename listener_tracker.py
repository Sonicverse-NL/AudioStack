import os
import time
import requests
import xml.etree.ElementTree as ET

def main():
    icecast_url = os.getenv('ICECAST_URL', 'https://user:pass@icecast.server:port/admin/listclients?mount=/stream')
    matomo_token_auth = os.getenv('MATOMO_TOKEN_AUTH', 'yourmatomoauthtoken')
    matomo_id_site = os.getenv('MATOMO_ID_SITE', '1')
    matomo_url_base = os.getenv('MATOMO_URL', 'https://my.matomo.server:port/matomo.php')

    while True:
        try:
            response = requests.get(icecast_url)
            response.raise_for_status()
            root = ET.fromstring(response.content)

            listeners = root.find('.//Listeners')
            if listeners is not None and int(listeners.text) > 0:
                print(f"[{time.strftime('%m-%j-%Y, %H:%M:%S')}]")
                for listener in root.findall('.//listener'):
                    # Check for X-Forwarded-For header in Icecast response
                    forwarded_ip = listener.find('X-Forwarded-For')
                    if forwarded_ip is not None and forwarded_ip.text:
                        ip = forwarded_ip.text
                    else:
                        ip = listener.find('IP').text
                    ua = listener.find('UserAgent').text

                    matomo_url = (
                        f"{matomo_url_base}?idsite={matomo_id_site}&rec=1&action_name=Stream%20Listener&"
                        f"url={requests.utils.quote('http://icecast.server:port/mount')}&apiv=1&pv_id=1&"
                        f"urlref={requests.utils.quote('http://icecast.server:port/mount')}&token_auth={matomo_token_auth}&"
                        f"ua={requests.utils.quote(ua)}&cip={ip}"
                    )

                    matomo_response = requests.get(matomo_url)
                    if matomo_response.status_code == 200:
                        print(f"Sent request to Matomo for {ip} (200)")
                    else:
                        print(f"Failed to contact Matomo for {ip}: {matomo_response.status_code}")
            else:
                print("No listeners connected.")
        except requests.RequestException as e:
            print(f"Error fetching Icecast data: {e}")
        except ET.ParseError as e:
            print(f"Error parsing Icecast XML: {e}")

        time.sleep(30)

if __name__ == "__main__":
    main()
