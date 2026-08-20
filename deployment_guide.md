# 🌐 How to Upload & Deploy "The Bead Room by Pallas" Website

Here are step-by-step instructions to upload your website to a live web server or hosting provider.

---

## 🚀 Method 1: Render.com (Recommended Free Node.js Hosting)

**Best for**: Complete Full-Stack hosting with live backend, product uploads, email inquiries, and order management.

1. **Prepare your project folder**:
   - Make sure your project folder [`the-bead-room`](file:///C:/Users/PRATEEK/.gemini/antigravity/scratch/the-bead-room) has `package.json`, `server.js`, `public/`, `data/`, and `uploads/`.

2. **Push to GitHub**:
   - Create a free repository on [GitHub.com](https://github.com).
   - Upload the files in `the-bead-room` to your repository.

3. **Deploy on Render**:
   - Go to [Render.com](https://render.com) and create a free account.
   - Click **New +** -> **Web Service**.
   - Connect your GitHub repository.
   - Configure the following settings:
     - **Name**: `the-bead-room`
     - **Environment**: `Node`
     - **Build Command**: `npm install`
     - **Start Command**: `node server.js`
   - Click **Create Web Service**.
   - Within 1-2 minutes, your website will be live with a URL like `https://the-bead-room.onrender.com`!

---

## 🏢 Method 2: Shared Hosting / cPanel (Hostinger, GoDaddy, Bluehost, Namecheap)

**Best for**: Custom domain names (e.g. `www.thebeadroombypallas.com`).

### Scenario A: cPanel with Node.js Support (Hostinger / cPanel Node.js Selector)
1. Compress your `the-bead-room` folder into a `.zip` file.
2. Log into your hosting account **cPanel** -> Open **File Manager**.
3. Navigate to `public_html` and upload your `.zip` file.
4. Extract the `.zip` file contents inside `public_html`.
5. In cPanel, find **Setup Node.js App** (or Node.js Manager):
   - Click **Create Application**.
   - **Application Root**: `public_html`
   - **Application Startup File**: `server.js`
   - **Node.js Version**: Select 18.x or 20.x.
   - Click **Create** and then **Run NPM Install**.
6. Click **Restart Application**. Your full-stack app is live on your custom domain!

### Scenario B: Standard Static Web Hosting (Without Node.js)
1. Copy all contents of the `public/` directory (`index.html`, `admin.html`, `css/`, `js/`, `images/`) directly into `public_html`.
2. The storefront (`index.html`) will instantly work with all products, search, category filters, and cart features!

---

## ⚡ Method 3: Vercel / Netlify (Fast 1-Click Deployment)

1. Create a free account on [Vercel.com](https://vercel.com).
2. Install Vercel CLI or import your GitHub repository.
3. Click **Deploy**. Vercel will automatically build and publish your storefront live!

---

## ✉️ Email Configuration on Live Server

Once your server is live, log into your Admin Panel at `https://your-domain.com/admin.html`:
1. Go to the **Email & Store Config** tab.
2. Enter your SMTP details (e.g., Gmail SMTP or Hostinger Webmail):
   - **SMTP Host**: `smtp.gmail.com`
   - **SMTP Port**: `587`
   - **SMTP Username**: `sarakamdar26@gmail.com`
   - **SMTP Password**: Your App Password (generated from Google Account settings)
3. Click **Send Test Email** to verify live email delivery!
