# =============================================================================
# HTTP-to-Syslog Forwarder
# Description:
#   This script starts a local HTTP server to receive logs from the Demo Web App,
#   then forwards them in Syslog (UDP) format to your specified Wazuh server.
#
# How to use:
#   1. Run this script in a PowerShell terminal.
#   2. When prompted, enter your Wazuh server IP address and press Enter.
#   3. Keep this terminal window open to continue forwarding logs.
# =============================================================================

# --- Configuration Section ---
$wazuhServerIp = ""
# Prompt the user for the Wazuh Server IP until a value is entered
do {
    $wazuhServerIp = Read-Host "Please enter the Wazuh Server IP Address"
} while ([string]::IsNullOrWhiteSpace($wazuhServerIp))

$wazuhServerPort = 514 # Standard Syslog UDP port
$localListenPrefix = "http://localhost:8088/" # The Demo Web App connects to this address

# --- Main Program ---
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($localListenPrefix)

try {
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "HTTP-to-Syslog Forwarder Started" -ForegroundColor White
    Write-Host " - Listening on: $($localListenPrefix)" -ForegroundColor Green
    Write-Host " - Forwarding to: $($wazuhServerIp):$($wazuhServerPort) (UDP)" -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Cyan
    
    $listener.Start()

    # Continuously receive requests
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        
        # Add CORS header for all responses
        $response.AddHeader("Access-Control-Allow-Origin", "*")

        # Handle health check from the web app
        if ($request.HttpMethod -eq 'GET') {
            $response.StatusCode = 200
            $responseMessage = [System.Text.Encoding]::UTF8.GetBytes("Forwarder is running.")
            $response.ContentLength64 = $responseMessage.Length
            $response.OutputStream.Write($responseMessage, 0, $responseMessage.Length)
        }
        # Handle log forwarding
        elseif ($request.HttpMethod -eq 'POST') {
            # Read the log content
            $streamReader = [System.IO.StreamReader]::new($request.InputStream, $request.ContentEncoding)
            $logMessage = $streamReader.ReadToEnd()
            $streamReader.Close()

            # Display and forward the log
            Write-Host "[$(Get-Date -Format "HH:mm:ss")] Log Received: $logMessage" -ForegroundColor White
            
            $udpClient = New-Object System.Net.Sockets.UdpClient
            $bytesToSend = [System.Text.Encoding]::UTF8.GetBytes($logMessage)
            $udpClient.Send($bytesToSend, $bytesToSend.Length, $wazuhServerIp, $wazuhServerPort)
            $udpClient.Close()

            Write-Host " -> Forwarded successfully to Wazuh" -ForegroundColor Green
            
            # Respond to the web app
            $response.StatusCode = 200
        }
        
        $response.Close()
    }
}
catch {
    Write-Host "[ERROR] Script execution failed: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    # Ensure the listener is stopped when the script ends
    if ($listener.IsListening) {
        $listener.Stop()
        Write-Host "HTTP listener has been stopped." -ForegroundColor Yellow
    }
}

