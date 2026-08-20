# ==============================================================================
# The Bead Room by Pallas - Full-Stack E-Commerce & Workshop Server
# Native PowerShell REST API & Static File Server
# Default Port: 3000 | Configured Email: sarakamdar26@gmail.com
# ==============================================================================

$port = 3000
$rootPath = $PSScriptRoot
if (-not $rootPath) { $rootPath = Get-Location }
$publicPath = Join-Path $rootPath "public"
$dataPath = Join-Path $rootPath "data"
$uploadsPath = Join-Path $rootPath "uploads"
$dbFile = Join-Path $dataPath "store.json"

# Ensure directories exist
if (-not (Test-Path $dataPath)) { New-Item -ItemType Directory -Path $dataPath -Force | Out-Null }
if (-not (Test-Path $uploadsPath)) { New-Item -ItemType Directory -Path $uploadsPath -Force | Out-Null }
if (-not (Test-Path $publicPath)) { New-Item -ItemType Directory -Path $publicPath -Force | Out-Null }

Write-Host "===============================================================" -ForegroundColor Magenta
Write-Host " 🌸 THE BEAD ROOM BY PALLAS - E-COMMERCE & WORKSHOP SERVER 🎨" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Magenta
Write-Host " [Web Storefront] -> http://localhost:$port/" -ForegroundColor Green
Write-Host " [Admin Portal]   -> http://localhost:$port/admin.html" -ForegroundColor Yellow
Write-Host " [Database]       -> $dbFile" -ForegroundColor Gray
Write-Host " [Store Email]    -> sarakamdar26@gmail.com" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Magenta

# Database Helper Functions
function Get-Database {
    if (Test-Path $dbFile) {
        $json = Get-Content $dbFile -Raw -Encoding UTF8
        return ConvertFrom-Json $json
    }
    return [PSCustomObject]@{
        settings = [PSCustomObject]@{
            storeName = "The Bead Room by Pallas"
            email = "sarakamdar26@gmail.com"
            address = "107, Amba Appts., Surendranagar, Nagpur"
        }
        products = @()
        enquiries = @()
        orders = @()
    }
}

function Save-Database ($data) {
    $json = ConvertTo-Json $data -Depth 10
    [System.IO.File]::WriteAllText($dbFile, $json, [System.Text.Encoding]::UTF8)
}

# Email Dispatcher Function
function Send-StoreEmail ($toEmail, $subject, $htmlBody, $settings) {
    $result = @{
        success = $false
        message = ""
        mode = "preview"
        previewLink = ""
    }

    $smtpHost = $settings.smtp.host
    $smtpUser = $settings.smtp.user
    $smtpPass = $settings.smtp.pass
    $smtpPort = [int]($settings.smtp.port)
    if ($smtpPort -eq 0) { $smtpPort = 587 }
    $fromEmail = if ($settings.smtp.fromEmail) { $settings.smtp.fromEmail } else { "sarakamdar26@gmail.com" }

    Write-Host "[EMAIL DISPATCHER] To: $toEmail | Subject: $subject" -ForegroundColor Cyan

    if ($smtpHost -and $smtpUser -and $smtpPass) {
        try {
            $smtp = New-Object System.Net.Mail.SmtpClient($smtpHost, $smtpPort)
            $smtp.EnableSsl = $settings.smtp.secure
            $smtp.Credentials = New-Object System.Net.NetworkCredential($smtpUser, $smtpPass)
            
            $mail = New-Object System.Net.Mail.MailMessage
            $mail.From = New-Object System.Net.Mail.MailAddress($fromEmail, $settings.storeName)
            $mail.To.Add($toEmail)
            $mail.Subject = $subject
            $mail.Body = $htmlBody
            $mail.IsBodyHtml = $true
            
            $smtp.Send($mail)
            $result.success = $true
            $result.message = "Email successfully delivered to $toEmail via $smtpHost"
            $result.mode = "smtp"
            Write-Host "[EMAIL SUCCESS] Sent to $toEmail" -ForegroundColor Green
        }
        catch {
            $result.success = $false
            $result.message = "SMTP Error: " + $_.Exception.Message
            Write-Host "[EMAIL SMTP ERROR] $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        # Saved into simulated outbox and logs with full HTML preview
        $outboxDir = Join-Path $rootPath "data\outbox"
        if (-not (Test-Path $outboxDir)) { New-Item -ItemType Directory -Path $outboxDir -Force | Out-Null }
        $emailId = "email-" + [System.Guid]::NewGuid().ToString().Substring(0, 8) + ".html"
        $emailFilePath = Join-Path $outboxDir $emailId
        [System.IO.File]::WriteAllText($emailFilePath, $htmlBody, [System.Text.Encoding]::UTF8)

        $result.success = $true
        $result.message = "Notification registered! (SMTP not configured in Admin -> Saved to outbox: $emailId)"
        $result.mode = "outbox"
        $result.previewLink = "/data/outbox/$emailId"
        Write-Host "[EMAIL LOGGED] Recipient: $toEmail (Configure SMTP in Admin Settings for live delivery)" -ForegroundColor Yellow
    }

    return $result
}

# MIME Types Dictionary
$mimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".htm"  = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".gif"  = "image/gif"
    ".svg"  = "image/svg+xml"
    ".ico"  = "image/x-icon"
    ".webp" = "image/webp"
    ".woff" = "font/woff"
    ".woff2"= "font/woff2"
    ".ttf"  = "font/ttf"
}

# Start HTTP Listener
$listener = New-Object System.Net.HttpListener
$prefix = "http://localhost:$port/"
$listener.Prefixes.Add($prefix)

try {
    $listener.Start()
    Write-Host ">>> Server is active and listening on $prefix" -ForegroundColor Green
} catch {
    Write-Host "Port $port in use. Trying port 8080..." -ForegroundColor Yellow
    $port = 8080
    $prefix = "http://localhost:$port/"
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add($prefix)
    $listener.Start()
    Write-Host ">>> Server is active and listening on $prefix" -ForegroundColor Green
}

# Main Server Loop
try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        # CORS Headers
        $response.Headers.Add("Access-Control-Allow-Origin", "*")
        $response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
        $response.Headers.Add("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Requested-With")

        if ($request.HttpMethod -eq "OPTIONS") {
            $response.StatusCode = 200
            $response.Close()
            continue
        }

        $urlPath = $request.Url.AbsolutePath
        $httpMethod = $request.HttpMethod

        # ==============================================================================
        # REST API ROUTING
        # ==============================================================================

        # --- GET /api/products ---
        if ($urlPath -eq "/api/products" -and $httpMethod -eq "GET") {
            $db = Get-Database
            $category = $request.QueryString["category"]
            $type = $request.QueryString["type"]
            $search = $request.QueryString["search"]
            $products = $db.products

            if ($category -and $category -ne "All") {
                $products = $products | Where-Object { $_.category -eq $category }
            }
            if ($type) {
                $products = $products | Where-Object { $_.type -eq $type }
            }
            if ($search) {
                $q = $search.ToLower()
                $products = $products | Where-Object { 
                    ($_.name -and $_.name.ToLower().Contains($q)) -or 
                    ($_.description -and $_.description.ToLower().Contains($q)) -or
                    ($_.category -and $_.category.ToLower().Contains($q))
                }
            }

            $responseBytes = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $products -Depth 10))
            $response.ContentType = "application/json; charset=utf-8"
            $response.StatusCode = 200
            $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
            $response.Close()
            continue
        }

        # --- GET /api/products/:id ---
        if ($urlPath -match "^/api/products/([^/]+)$" -and $httpMethod -eq "GET") {
            $id = $Matches[1]
            $db = Get-Database
            $product = $db.products | Where-Object { $_.id -eq $id } | Select-Object -First 1
            if ($product) {
                $json = ConvertTo-Json $product -Depth 10
                $responseBytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                $response.ContentType = "application/json; charset=utf-8"
                $response.StatusCode = 200
                $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
            } else {
                $response.StatusCode = 404
                $responseBytes = [System.Text.Encoding]::UTF8.GetBytes('{"error":"Product not found"}')
                $response.ContentType = "application/json"
                $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
            }
            $response.Close()
            continue
        }

        # --- POST /api/products ---
        if ($urlPath -eq "/api/products" -and $httpMethod -eq "POST") {
            $reader = New-Object System.IO.StreamReader($request.InputStream, [System.Text.Encoding]::UTF8)
            $body = $reader.ReadToEnd()
            $reader.Close()

            $newProduct = ConvertFrom-Json $body
            $db = Get-Database

            if (-not $newProduct.id) {
                $newProduct | Add-Member -NotePropertyName "id" -NotePropertyValue ("prod-" + [System.Guid]::NewGuid().ToString().Substring(0, 8))
            }
            if (-not $newProduct.createdAt) {
                $newProduct | Add-Member -NotePropertyName "createdAt" -NotePropertyValue (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
            }
            if (-not $newProduct.rating) {
                $newProduct | Add-Member -NotePropertyName "rating" -NotePropertyValue 5.0
                $newProduct | Add-Member -NotePropertyName "reviewsCount" -NotePropertyValue 1
            }

            $currentList = [System.Collections.ArrayList]@($db.products)
            $currentList.Insert(0, $newProduct)
            $db.products = $currentList
            Save-Database $db

            $responseBytes = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $newProduct -Depth 10))
            $response.ContentType = "application/json; charset=utf-8"
            $response.StatusCode = 201
            $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
            $response.Close()
            Write-Host "[PRODUCT ADDED] $($newProduct.name) (₹$($newProduct.price))" -ForegroundColor Green
            continue
        }

        # --- PUT /api/products/:id ---
        if ($urlPath -match "^/api/products/([^/]+)$" -and $httpMethod -eq "PUT") {
            $id = $Matches[1]
            $reader = New-Object System.IO.StreamReader($request.InputStream, [System.Text.Encoding]::UTF8)
            $body = $reader.ReadToEnd()
            $reader.Close()

            $updatedProps = ConvertFrom-Json $body
            $db = Get-Database
            $updated = $null

            for ($i = 0; $i -lt $db.products.Count; $i++) {
                if ($db.products[$i].id -eq $id) {
                    $item = $db.products[$i]
                    foreach ($prop in $updatedProps.PSObject.Properties) {
                        if ($item.PSObject.Properties[$prop.Name]) {
                            $item.$($prop.Name) = $prop.Value
                        } else {
                            $item | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value
                        }
                    }
                    $db.products[$i] = $item
                    $updated = $item
                    break
                }
            }

            if ($updated) {
                Save-Database $db
                $responseBytes = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $updated -Depth 10))
                $response.ContentType = "application/json; charset=utf-8"
                $response.StatusCode = 200
                $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
            } else {
                $response.StatusCode = 404
                $responseBytes = [System.Text.Encoding]::UTF8.GetBytes('{"error":"Product not found"}')
                $response.ContentType = "application/json"
                $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
            }
            $response.Close()
            continue
        }

        # --- DELETE /api/products/:id ---
        if ($urlPath -match "^/api/products/([^/]+)$" -and $httpMethod -eq "DELETE") {
            $id = $Matches[1]
            $db = Get-Database
            $db.products = @($db.products | Where-Object { $_.id -ne $id })
            Save-Database $db

            $responseBytes = [System.Text.Encoding]::UTF8.GetBytes('{"success":true,"message":"Product deleted"}')
            $response.ContentType = "application/json; charset=utf-8"
            $response.StatusCode = 200
            $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
            $response.Close()
            Write-Host "[PRODUCT DELETED] ID: $id" -ForegroundColor Red
            continue
        }

        # --- GET /api/enquiries ---
        if ($urlPath -eq "/api/enquiries" -and $httpMethod -eq "GET") {
            $db = Get-Database
            $responseBytes = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $db.enquiries -Depth 10))
            $response.ContentType = "application/json; charset=utf-8"
            $response.StatusCode = 200
            $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
            $response.Close()
            continue
        }

        # --- POST /api/enquiries (Submit Customer Inquiry + Send Email) ---
        if ($urlPath -eq "/api/enquiries" -and $httpMethod -eq "POST") {
            $reader = New-Object System.IO.StreamReader($request.InputStream, [System.Text.Encoding]::UTF8)
            $body = $reader.ReadToEnd()
            $reader.Close()

            $enq = ConvertFrom-Json $body
            $db = Get-Database
            $settings = $db.settings

            $enqId = "enq-" + [System.Guid]::NewGuid().ToString().Substring(0, 8)
            if (-not $enq.id) { $enq | Add-Member -NotePropertyName "id" -NotePropertyValue $enqId }
            if (-not $enq.status) { $enq | Add-Member -NotePropertyName "status" -NotePropertyValue "New" }
            if (-not $enq.createdAt) { $enq | Add-Member -NotePropertyName "createdAt" -NotePropertyValue (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ") }

            # Prepend to database
            $enqList = [System.Collections.ArrayList]@($db.enquiries)
            $enqList.Insert(0, $enq)
            $db.enquiries = $enqList
            Save-Database $db

            # Build HTML Notification for Store Owner (sarakamdar26@gmail.com)
            $recipientEmail = if ($settings.email) { $settings.email } else { "sarakamdar26@gmail.com" }
            $emailSubject = "🌸 New Inquiry: $($enq.subject) - The Bead Room by Pallas"
            $htmlBody = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #fffaf5; color: #2d1a24; margin: 0; padding: 20px; }
        .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 16px; padding: 32px; border: 1px solid #fce7f3; box-shadow: 0 4px 20px rgba(225, 29, 72, 0.08); }
        .header { text-align: center; border-bottom: 2px solid #fdf2f4; padding-bottom: 20px; margin-bottom: 24px; }
        .logo { font-size: 24px; font-weight: 700; color: #be185d; }
        .tagline { font-size: 13px; color: #9d174d; margin-top: 4px; }
        .badge { display: inline-block; background: #fdf2f4; color: #db2777; font-weight: 600; padding: 6px 14px; border-radius: 20px; font-size: 13px; margin-bottom: 16px; }
        .field-group { margin-bottom: 16px; }
        .field-label { font-size: 12px; font-weight: bold; text-transform: uppercase; color: #831843; letter-spacing: 0.5px; }
        .field-value { font-size: 15px; color: #1e1b4b; background: #fdf4f5; padding: 12px 16px; border-radius: 8px; margin-top: 4px; }
        .message-box { background: #fff1f2; border-left: 4px solid #f43f5e; padding: 16px; border-radius: 8px; font-size: 15px; line-height: 1.6; margin-top: 6px; }
        .footer { text-align: center; margin-top: 30px; font-size: 12px; color: #9ca3af; border-top: 1px solid #f3f4f6; padding-top: 16px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">🌸 The Bead Room by Pallas</div>
            <div class="tagline">Handcrafted Jewellery & Curated Art Workshops in Nagpur</div>
        </div>
        <div class="badge">✨ New Customer Inquiry Received</div>
        <div class="field-group">
            <div class="field-label">Customer Name</div>
            <div class="field-value">$($enq.name)</div>
        </div>
        <div class="field-group">
            <div class="field-label">Email & Phone</div>
            <div class="field-value">📧 $($enq.email) &nbsp;|&nbsp; 📱 $($enq.phone)</div>
        </div>
        <div class="field-group">
            <div class="field-label">Interested In / Product</div>
            <div class="field-value">💖 $($enq.productName) ($($enq.subject))</div>
        </div>
        <div class="field-group">
            <div class="field-label">Preferred Contact Mode</div>
            <div class="field-value">💬 $($enq.preferredContact)</div>
        </div>
        <div class="field-group">
            <div class="field-label">Customer Message / Custom Requirements</div>
            <div class="message-box">$($enq.message)</div>
        </div>
        <div class="footer">
            Received on $(Get-Date -Format 'dd MMMM yyyy, hh:mm tt') | Studio: 107, Amba Appts., Surendranagar, Nagpur
        </div>
    </div>
</body>
</html>
"@

            # Dispatch Email
            $emailResult = Send-StoreEmail -toEmail $recipientEmail -subject $emailSubject -htmlBody $htmlBody -settings $settings

            $responseObj = @{
                success = $true
                enquiryId = $enq.id
                message = "Thank you! Your inquiry has been submitted and sent to $recipientEmail."
                emailStatus = $emailResult
            }

            $responseBytes = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $responseObj -Depth 10))
            $response.ContentType = "application/json; charset=utf-8"
            $response.StatusCode = 201
            $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
            $response.Close()
            Write-Host "[INQUIRY SUBMITTED] From: $($enq.name) ($($enq.email)) -> Notification to $recipientEmail" -ForegroundColor Magenta
            continue
        }

        # --- PATCH /api/enquiries/:id ---
        if ($urlPath -match "^/api/enquiries/([^/]+)$" -and $httpMethod -eq "PATCH") {
            $id = $Matches[1]
            $reader = New-Object System.IO.StreamReader($request.InputStream, [System.Text.Encoding]::UTF8)
            $body = $reader.ReadToEnd()
            $reader.Close()

            $patch = ConvertFrom-Json $body
            $db = Get-Database
            $found = $false

            foreach ($item in $db.enquiries) {
                if ($item.id -eq $id) {
                    if ($patch.status) { $item.status = $patch.status }
                    $found = $true
                    break
                }
            }

            if ($found) {
                Save-Database $db
                $responseBytes = [System.Text.Encoding]::UTF8.GetBytes('{"success":true,"message":"Status updated"}')
                $response.ContentType = "application/json"
                $response.StatusCode = 200
                $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
            } else {
                $response.StatusCode = 404
                $responseBytes = [System.Text.Encoding]::UTF8.GetBytes('{"error":"Enquiry not found"}')
                $response.ContentType = "application/json"
                $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
            }
            $response.Close()
            continue
        }

        # --- DELETE /api/enquiries/:id ---
        if ($urlPath -match "^/api/enquiries/([^/]+)$" -and $httpMethod -eq "DELETE") {
            $id = $Matches[1]
            $db = Get-Database
            $db.enquiries = @($db.enquiries | Where-Object { $_.id -ne $id })
            Save-Database $db
            $responseBytes = [System.Text.Encoding]::UTF8.GetBytes('{"success":true}')
            $response.ContentType = "application/json"
            $response.StatusCode = 200
            $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
            $response.Close()
            continue
        }

        # --- GET /api/orders ---
        if ($urlPath -eq "/api/orders" -and $httpMethod -eq "GET") {
            $db = Get-Database
            $responseBytes = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $db.orders -Depth 10))
            $response.ContentType = "application/json; charset=utf-8"
            $response.StatusCode = 200
            $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
            $response.Close()
            continue
        }

        # --- POST /api/orders (Create Order & Send Email Confirmation) ---
        if ($urlPath -eq "/api/orders" -and $httpMethod -eq "POST") {
            $reader = New-Object System.IO.StreamReader($request.InputStream, [System.Text.Encoding]::UTF8)
            $body = $reader.ReadToEnd()
            $reader.Close()

            $order = ConvertFrom-Json $body
            $db = Get-Database
            $settings = $db.settings

            $orderId = "ORD-2026-" + (Get-Random -Minimum 1000 -Maximum 9999)
            if (-not $order.id) { $order | Add-Member -NotePropertyName "id" -NotePropertyValue $orderId }
            if (-not $order.status) { $order | Add-Member -NotePropertyName "status" -NotePropertyValue "Processing" }
            if (-not $order.createdAt) { $order | Add-Member -NotePropertyName "createdAt" -NotePropertyValue (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ") }

            # Deduct stock
            if ($order.items) {
                foreach ($item in $order.items) {
                    foreach ($prod in $db.products) {
                        if ($prod.id -eq $item.id -and $prod.stock -ge $item.quantity) {
                            $prod.stock -= $item.quantity
                        }
                    }
                }
            }

            $orderList = [System.Collections.ArrayList]@($db.orders)
            $orderList.Insert(0, $order)
            $db.orders = $orderList
            Save-Database $db

            # Build Items HTML table
            $itemsHtml = ""
            if ($order.items) {
                foreach ($it in $order.items) {
                    $itemsHtml += "<tr><td style='padding:8px 12px; border-bottom:1px solid #fee2e2;'>$($it.name)</td><td style='padding:8px 12px; border-bottom:1px solid #fee2e2; text-align:center;'>$($it.quantity)</td><td style='padding:8px 12px; border-bottom:1px solid #fee2e2; text-align:right;'>₹$($it.price)</td></tr>"
                }
            }

            # Order Confirmation Email Body
            $recipientEmail = if ($settings.email) { $settings.email } else { "sarakamdar26@gmail.com" }
            $orderEmailHtml = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #fffaf5; color: #2d1a24; padding: 20px; }
        .card { max-width: 600px; margin: 0 auto; background: #fff; border-radius: 16px; padding: 30px; border: 1px solid #fbcfe8; box-shadow: 0 4px 15px rgba(0,0,0,0.05); }
        .header { text-align: center; border-bottom: 2px solid #fdf2f4; padding-bottom: 16px; }
        .order-title { font-size: 20px; font-weight: bold; color: #9d174d; }
        table { width: 100%; border-collapse: collapse; margin-top: 16px; font-size: 14px; }
        th { background: #fdf2f4; color: #831843; padding: 10px 12px; text-align: left; }
        .total-box { margin-top: 16px; padding: 16px; background: #fff1f2; border-radius: 8px; text-align: right; font-size: 16px; font-weight: bold; color: #be185d; }
    </style>
</head>
<body>
    <div class="card">
        <div class="header">
            <h2 style="color:#be185d; margin:0;">🌸 The Bead Room by Pallas</h2>
            <div class="order-title">✨ Order Confirmation: $($order.id)</div>
        </div>
        <p><strong>Customer:</strong> $($order.customer.name) ($($order.customer.email))</p>
        <p><strong>Shipping Address:</strong> $($order.customer.address)</p>
        <p><strong>Payment Method:</strong> $($order.paymentMethod)</p>
        
        <table>
            <thead>
                <tr><th>Item</th><th style="text-align:center;">Qty</th><th style="text-align:right;">Price</th></tr>
            </thead>
            <tbody>
                $itemsHtml
            </tbody>
        </table>

        <div class="total-box">
            Total Paid: ₹$($order.total) (Discount: ₹$($order.discount))
        </div>
        <p style="font-size:12px; color:#6b7280; text-align:center; margin-top:24px;">
            Studio: 107, Amba Appts., Surendranagar, Nagpur | Contact: sarakamdar26@gmail.com
        </p>
    </div>
</body>
</html>
"@

            # Send Notification to Store & Customer
            Send-StoreEmail -toEmail $recipientEmail -subject "🌸 New Order Placed: $($order.id) (₹$($order.total))" -htmlBody $orderEmailHtml -settings $settings | Out-Null
            if ($order.customer.email) {
                Send-StoreEmail -toEmail $order.customer.email -subject "🌸 Order Confirmed: $($order.id) - The Bead Room by Pallas" -htmlBody $orderEmailHtml -settings $settings | Out-Null
            }

            $responseBytes = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $order -Depth 10))
            $response.ContentType = "application/json; charset=utf-8"
            $response.StatusCode = 201
            $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
            $response.Close()
            Write-Host "[ORDER PLACED] $($order.id) Total: ₹$($order.total) for $($order.customer.name)" -ForegroundColor Green
            continue
        }

        # --- PATCH /api/orders/:id ---
        if ($urlPath -match "^/api/orders/([^/]+)$" -and $httpMethod -eq "PATCH") {
            $id = $Matches[1]
            $reader = New-Object System.IO.StreamReader($request.InputStream, [System.Text.Encoding]::UTF8)
            $body = $reader.ReadToEnd()
            $reader.Close()

            $patch = ConvertFrom-Json $body
            $db = Get-Database
            $found = $false

            foreach ($item in $db.orders) {
                if ($item.id -eq $id) {
                    if ($patch.status) { $item.status = $patch.status }
                    $found = $true
                    break
                }
            }

            if ($found) {
                Save-Database $db
                $responseBytes = [System.Text.Encoding]::UTF8.GetBytes('{"success":true,"message":"Order updated"}')
                $response.ContentType = "application/json"
                $response.StatusCode = 200
                $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
            } else {
                $response.StatusCode = 404
                $responseBytes = [System.Text.Encoding]::UTF8.GetBytes('{"error":"Order not found"}')
                $response.ContentType = "application/json"
                $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
            }
            $response.Close()
            continue
        }

        # --- GET /api/settings ---
        if ($urlPath -eq "/api/settings" -and $httpMethod -eq "GET") {
            $db = Get-Database
            $responseBytes = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $db.settings -Depth 10))
            $response.ContentType = "application/json; charset=utf-8"
            $response.StatusCode = 200
            $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
            $response.Close()
            continue
        }

        # --- PUT /api/settings ---
        if ($urlPath -eq "/api/settings" -and $httpMethod -eq "PUT") {
            $reader = New-Object System.IO.StreamReader($request.InputStream, [System.Text.Encoding]::UTF8)
            $body = $reader.ReadToEnd()
            $reader.Close()

            $newSettings = ConvertFrom-Json $body
            $db = Get-Database
            $db.settings = $newSettings
            Save-Database $db

            $responseBytes = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $db.settings -Depth 10))
            $response.ContentType = "application/json; charset=utf-8"
            $response.StatusCode = 200
            $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
            $response.Close()
            Write-Host "[SETTINGS UPDATED] Target Email: $($newSettings.email)" -ForegroundColor Cyan
            continue
        }

        # --- POST /api/test-email ---
        if ($urlPath -eq "/api/test-email" -and $httpMethod -eq "POST") {
            $db = Get-Database
            $settings = $db.settings
            $target = if ($settings.email) { $settings.email } else { "sarakamdar26@gmail.com" }

            $testHtml = "<h2>🌸 Test Email - The Bead Room by Pallas</h2><p>This is a verification email from your store backend. If you received this, your email configuration is working perfectly!</p><p>Studio Address: 107, Amba Appts., Surendranagar, Nagpur</p>"
            $res = Send-StoreEmail -toEmail $target -subject "🌸 Test Email from The Bead Room by Pallas Backend" -htmlBody $testHtml -settings $settings

            $responseBytes = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $res -Depth 10))
            $response.ContentType = "application/json; charset=utf-8"
            $response.StatusCode = 200
            $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
            $response.Close()
            continue
        }

        # --- POST /api/upload (Base64 or multipart upload handler) ---
        if ($urlPath -eq "/api/upload" -and $httpMethod -eq "POST") {
            $reader = New-Object System.IO.StreamReader($request.InputStream, [System.Text.Encoding]::UTF8)
            $body = $reader.ReadToEnd()
            $reader.Close()

            try {
                $uploadData = ConvertFrom-Json $body
                $base64 = $uploadData.base64
                $fileName = $uploadData.fileName
                $extension = [System.IO.Path]::GetExtension($fileName)
                if (-not $extension) { $extension = ".jpg" }

                # Remove header if present (e.g. data:image/png;base64,)
                if ($base64 -match "^data:image\/[^;]+;base64,(.+)$") {
                    $base64 = $Matches[1]
                }

                $bytes = [System.Convert]::FromBase64String($base64)
                $safeName = "upload-" + [System.Guid]::NewGuid().ToString().Substring(0, 8) + $extension
                $filePath = Join-Path $uploadsPath $safeName
                [System.IO.File]::WriteAllBytes($filePath, $bytes)

                $fileUrl = "/uploads/$safeName"
                $resObj = @{ success = $true; url = $fileUrl; fileName = $safeName }
                $responseBytes = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $resObj))
                $response.ContentType = "application/json"
                $response.StatusCode = 200
                $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
                Write-Host "[FILE UPLOADED] Saved to $fileUrl" -ForegroundColor Green
            } catch {
                $response.StatusCode = 400
                $responseBytes = [System.Text.Encoding]::UTF8.GetBytes('{"error":"Failed to process image upload"}')
                $response.ContentType = "application/json"
                $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
            }
            $response.Close()
            continue
        }

        # ==============================================================================
        # STATIC FILE SERVING
        # ==============================================================================
        $reqPath = $urlPath.TrimStart('/')
        if (-not $reqPath) { $reqPath = "index.html" }
        $reqPath = $reqPath.Replace('/', '\')

        # Determine target file
        $targetFile = $null
        if ($reqPath.StartsWith("uploads\")) {
            $sub = $reqPath.Substring(8)
            $targetFile = Join-Path $uploadsPath $sub
        } elseif ($reqPath.StartsWith("data\outbox\")) {
            $sub = $reqPath.Substring(12)
            $targetFile = Join-Path (Join-Path $dataPath "outbox") $sub
        } else {
            $targetFile = Join-Path $publicPath $reqPath
        }

        if (Test-Path $targetFile -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($targetFile).ToLower()
            $mime = if ($mimeTypes.ContainsKey($ext)) { $mimeTypes[$ext] } else { "application/octet-stream" }

            $bytes = [System.IO.File]::ReadAllBytes($targetFile)
            $response.ContentType = $mime
            $response.ContentLength64 = $bytes.Length
            $response.StatusCode = 200
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            # 404 Not Found
            $response.StatusCode = 404
            $notFoundHtml = "<html><body style='font-family:sans-serif; text-align:center; padding:50px;'><h2>404 - Page Not Found</h2><p><a href='/'>Go to Home</a> | <a href='/admin.html'>Go to Admin</a></p></body></html>"
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($notFoundHtml)
            $response.ContentType = "text/html"
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        }
        $response.Close()
    }
}
finally {
    $listener.Stop()
    $listener.Close()
    Write-Host "Server stopped." -ForegroundColor Red
}
