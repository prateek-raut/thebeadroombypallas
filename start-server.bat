@echo off
title The Bead Room by Pallas - E-Commerce Server
echo ========================================================
echo   🌸 Starting The Bead Room by Pallas Server 🎨
echo ========================================================
echo   Web Storefront : http://localhost:3000/
echo   Admin Portal   : http://localhost:3000/admin.html
echo   Store Email    : sarakamdar26@gmail.com
echo ========================================================
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0server.ps1"
pause
