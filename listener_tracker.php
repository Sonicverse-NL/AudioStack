<?php
// Get listener information from Icecast XML
$iceurl = getenv('ICECAST_URL') ?: 'https://user:pass@icecast.server:port/admin/listclients?mount=/stream';
$token_auth = getenv('MATOMO_TOKEN_AUTH') ?: 'yourmatomoauthtoken';
$id_site = getenv('MATOMO_ID_SITE') ?: '1';
$maturl_base = getenv('MATOMO_URL') ?: 'https://my.matomo.server:port/matomo.php';

while (true) {
    $iceresponse = file_get_contents($iceurl);

    // Get each listener's info
    $xml = simplexml_load_string($iceresponse);
    if (isset($xml->source->Listeners)) {
        $listeners = (string)$xml->source->Listeners;
        echo "[" . date("m-j-Y, H:i:s") . "]\r\n";
        if ($listeners > 0) {
            foreach($xml->source->listener as $listener) {
                $ip = $listener->IP;
                $ua = $listener->UserAgent;
                // Build the Matomo URL and send
                $maturl = $maturl_base . '?'
                    . 'idsite=' . $id_site . '&'
                    . 'rec=1&'
                    . 'action_name=Stream%20Listener&'
                    . 'url=' . urlencode('http://icecast.server:port/mount') . '&'
                    . 'apiv=1&'
                    . 'pv_id=1&'
                    . 'urlref=' . urlencode('http://icecast.server:port/mount') . '&'
                    . 'token_auth=' . $token_auth . '&'
                    . 'ua=' . urlencode($ua) . '&'
                    . 'cip=' . $ip;
                $curl = curl_init($maturl);
                curl_setopt($curl, CURLOPT_RETURNTRANSFER, true);
                $matresponse = curl_exec($curl);
                $matresponsecode = curl_getinfo($curl, CURLINFO_HTTP_CODE);
                if ($matresponse === false) {
                    echo "Could not contact Matomo for " . $ip . ": " . curl_error($curl) . "\r\n";
                } else {
                    echo 'Sent request to Matomo for ' . $ip . " (" . $matresponsecode . ")\r\n";
                }
                curl_close($curl);
            }
            echo "Complete!\r\n\n";
        } else {
            echo "No listeners connected.\r\nComplete!\r\n\n";
        }
    }
    sleep(30);
}
?>
