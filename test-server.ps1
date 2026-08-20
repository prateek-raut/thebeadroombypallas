# Test Script for The Bead Room by Pallas Backend Server
$baseUrl = "http://localhost:3000"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Testing The Bead Room by Pallas Backend" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Cyan

# 1. Test Storefront Home
try {
    $resHome = Invoke-WebRequest -Uri "$baseUrl/" -UseBasicParsing
    Write-Host "[PASS] Storefront (index.html) returned HTTP $($resHome.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] Storefront failed: $_" -ForegroundColor Red
}

# 2. Test Admin Portal
try {
    $resAdmin = Invoke-WebRequest -Uri "$baseUrl/admin.html" -UseBasicParsing
    Write-Host "[PASS] Admin Portal (admin.html) returned HTTP $($resAdmin.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] Admin Portal failed: $_" -ForegroundColor Red
}

# 3. Test GET /api/products
try {
    $resProducts = Invoke-RestMethod -Uri "$baseUrl/api/products" -Method Get
    Write-Host "[PASS] GET /api/products returned $($resProducts.Count) products" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] GET /api/products failed: $_" -ForegroundColor Red
}

# 4. Test POST /api/enquiries (Inquiry Submission for Sara Kamdar)
try {
    $enqBody = @{
        name = "Kavita Singhal"
        email = "kavita.s@example.com"
        phone = "+91 99887 76655"
        subject = "Custom Beaded Bracelet Order"
        productName = "Aurora Rainbow Charm Bracelet Stack"
        message = "Hi Sara, would love to order 3 customized matching rainbow charm stacks for a college reunion!"
        preferredContact = "WhatsApp"
    } | ConvertTo-Json

    $resEnq = Invoke-RestMethod -Uri "$baseUrl/api/enquiries" -Method Post -Body $enqBody -ContentType "application/json"
    Write-Host "[PASS] POST /api/enquiries successful! ID: $($resEnq.enquiryId)" -ForegroundColor Green
    Write-Host "       Email Status: $($resEnq.emailStatus.message)" -ForegroundColor Cyan
} catch {
    Write-Host "[FAIL] POST /api/enquiries failed: $_" -ForegroundColor Red
}

# 5. Test POST /api/orders (Pan-India Order Placement)
try {
    $orderBody = @{
        customer = @{
            name = "Meera Nair"
            email = "meera.nair@example.com"
            phone = "+91 98111 22334"
            address = "Flat 101, Lotus Palms, Koregaon Park, Pune - 411001"
        }
        items = @(
            @{ id = "prod-1"; name = "Pastel Bloom Daisy & Freshwater Pearl Choker"; price = 899; quantity = 1 }
        )
        subtotal = 899
        discount = 0
        shipping = 79
        total = 978
        paymentMethod = "UPI / GPay"
    } | ConvertTo-Json -Depth 5

    $resOrder = Invoke-RestMethod -Uri "$baseUrl/api/orders" -Method Post -Body $orderBody -ContentType "application/json"
    Write-Host "[PASS] POST /api/orders successful! Order ID: $($resOrder.id), Total: ₹$($resOrder.total)" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] POST /api/orders failed: $_" -ForegroundColor Red
}

# 6. Test GET /api/settings
try {
    $resSettings = Invoke-RestMethod -Uri "$baseUrl/api/settings" -Method Get
    Write-Host "[PASS] GET /api/settings: Store = $($resSettings.storeName), Email = $($resSettings.email)" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] GET /api/settings failed: $_" -ForegroundColor Red
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "All Verification Tests Completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
