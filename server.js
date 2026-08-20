const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const nodemailer = require('nodemailer');

const app = express();
const PORT = process.env.PORT || 3000;
const DB_PATH = path.join(__dirname, 'data', 'store.json');
const UPLOADS_DIR = path.join(__dirname, 'uploads');

// Ensure directories
if (!fs.existsSync(path.join(__dirname, 'data'))) fs.mkdirSync(path.join(__dirname, 'data'));
if (!fs.existsSync(UPLOADS_DIR)) fs.mkdirSync(UPLOADS_DIR);

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.use(express.static(path.join(__dirname, 'public')));
app.use('/uploads', express.static(UPLOADS_DIR));
app.use('/data/outbox', express.static(path.join(__dirname, 'data', 'outbox')));

// Multer storage
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, UPLOADS_DIR),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.jpg';
    cb(null, `upload-${Date.now()}-${Math.round(Math.random() * 1E9)}${ext}`);
  }
});
const upload = multer({ storage });

// Helper to read & write DB
function getDatabase() {
  if (fs.existsSync(DB_PATH)) {
    return JSON.parse(fs.readFileSync(DB_PATH, 'utf8'));
  }
  return {
    settings: {
      storeName: "The Bead Room by Pallas",
      email: "sarakamdar26@gmail.com",
      address: "107, Amba Appts., Surendranagar, Nagpur"
    },
    products: [],
    enquiries: [],
    orders: []
  };
}

function saveDatabase(data) {
  fs.writeFileSync(DB_PATH, JSON.stringify(data, null, 2), 'utf8');
}

// Send email function
async function sendStoreEmail(toEmail, subject, htmlBody, settings) {
  const smtp = settings.smtp || {};
  if (smtp.host && smtp.user && smtp.pass) {
    try {
      const transporter = nodemailer.createTransporter({
        host: smtp.host,
        port: parseInt(smtp.port) || 587,
        secure: !!smtp.secure,
        auth: { user: smtp.user, pass: smtp.pass }
      });
      await transporter.sendMail({
        from: `"${settings.storeName || 'The Bead Room'}" <${smtp.fromEmail || 'sarakamdar26@gmail.com'}>`,
        to: toEmail,
        subject,
        html: htmlBody
      });
      return { success: true, mode: 'smtp' };
    } catch (err) {
      console.error('SMTP Error:', err);
      return { success: false, error: err.message };
    }
  } else {
    const outbox = path.join(__dirname, 'data', 'outbox');
    if (!fs.existsSync(outbox)) fs.mkdirSync(outbox);
    const file = `email-${Date.now()}.html`;
    fs.writeFileSync(path.join(outbox, file), htmlBody, 'utf8');
    return { success: true, mode: 'outbox', preview: `/data/outbox/${file}` };
  }
}

// API Routes
app.get('/api/products', (req, res) => {
  const db = getDatabase();
  let products = db.products || [];
  const { category, type, search } = req.query;

  if (category && category !== 'All') {
    products = products.filter(p => p.category === category);
  }
  if (type) {
    products = products.filter(p => p.type === type);
  }
  if (search) {
    const q = search.toLowerCase();
    products = products.filter(p =>
      (p.name && p.name.toLowerCase().includes(q)) ||
      (p.description && p.description.toLowerCase().includes(q)) ||
      (p.category && p.category.toLowerCase().includes(q))
    );
  }
  res.json(products);
});

app.get('/api/products/:id', (req, res) => {
  const db = getDatabase();
  const prod = (db.products || []).find(p => p.id === req.params.id);
  if (prod) res.json(prod);
  else res.status(404).json({ error: 'Product not found' });
});

app.post('/api/products', upload.single('imageFile'), (req, res) => {
  const db = getDatabase();
  const data = req.body;
  
  if (req.file) {
    data.image = `/uploads/${req.file.filename}`;
  }

  const newProduct = {
    id: data.id || `prod-${Date.now()}`,
    name: data.name,
    category: data.category || 'Necklaces',
    type: data.type || 'jewellery',
    price: parseFloat(data.price) || 0,
    originalPrice: parseFloat(data.originalPrice) || 0,
    image: data.image || '/images/necklace_floral.jpg',
    badge: data.badge || 'New',
    stock: parseInt(data.stock) || 10,
    rating: parseFloat(data.rating) || 5.0,
    reviewsCount: parseInt(data.reviewsCount) || 1,
    description: data.description || '',
    details: typeof data.details === 'string' ? JSON.parse(data.details || '{}') : (data.details || {}),
    featured: data.featured === true || data.featured === 'true',
    createdAt: new Date().toISOString()
  };

  db.products = db.products || [];
  db.products.unshift(newProduct);
  saveDatabase(db);
  res.status(201).json(newProduct);
});

app.put('/api/products/:id', (req, res) => {
  const db = getDatabase();
  const idx = (db.products || []).findIndex(p => p.id === req.params.id);
  if (idx !== -1) {
    db.products[idx] = { ...db.products[idx], ...req.body };
    saveDatabase(db);
    res.json(db.products[idx]);
  } else {
    res.status(404).json({ error: 'Product not found' });
  }
});

app.delete('/api/products/:id', (req, res) => {
  const db = getDatabase();
  db.products = (db.products || []).filter(p => p.id !== req.params.id);
  saveDatabase(db);
  res.json({ success: true });
});

app.get('/api/enquiries', (req, res) => {
  const db = getDatabase();
  res.json(db.enquiries || []);
});

app.post('/api/enquiries', async (req, res) => {
  const db = getDatabase();
  const enq = {
    id: `enq-${Date.now()}`,
    name: req.body.name,
    email: req.body.email,
    phone: req.body.phone,
    subject: req.body.subject,
    productName: req.body.productName || 'General Inquiry',
    productId: req.body.productId || '',
    message: req.body.message,
    preferredContact: req.body.preferredContact || 'WhatsApp',
    status: 'New',
    createdAt: new Date().toISOString()
  };

  db.enquiries = db.enquiries || [];
  db.enquiries.unshift(enq);
  saveDatabase(db);

  const targetEmail = db.settings?.email || 'sarakamdar26@gmail.com';
  const html = `
    <div style="font-family:sans-serif; max-width:600px; margin:auto; border:1px solid #fbcfe8; padding:24px; border-radius:12px; background:#fffaf5;">
      <h2 style="color:#be185d;">🌸 The Bead Room by Pallas - New Inquiry</h2>
      <p><strong>Customer:</strong> ${enq.name}</p>
      <p><strong>Email:</strong> ${enq.email} | <strong>Phone:</strong> ${enq.phone}</p>
      <p><strong>Subject / Item:</strong> ${enq.subject} (${enq.productName})</p>
      <p><strong>Message:</strong></p>
      <div style="background:#fdf2f4; padding:12px; border-radius:8px;">${enq.message}</div>
      <hr style="border:none; border-top:1px solid #fce7f3; margin:20px 0;">
      <p style="font-size:12px; color:#6b7280;">107, Amba Appts., Surendranagar, Nagpur</p>
    </div>
  `;
  const emailRes = await sendStoreEmail(targetEmail, `🌸 New Inquiry from ${enq.name}: ${enq.subject}`, html, db.settings);

  res.status(201).json({ success: true, enquiryId: enq.id, emailStatus: emailRes });
});

app.patch('/api/enquiries/:id', (req, res) => {
  const db = getDatabase();
  const enq = (db.enquiries || []).find(e => e.id === req.params.id);
  if (enq) {
    if (req.body.status) enq.status = req.body.status;
    saveDatabase(db);
    res.json({ success: true });
  } else {
    res.status(404).json({ error: 'Enquiry not found' });
  }
});

app.delete('/api/enquiries/:id', (req, res) => {
  const db = getDatabase();
  db.enquiries = (db.enquiries || []).filter(e => e.id !== req.params.id);
  saveDatabase(db);
  res.json({ success: true });
});

app.get('/api/orders', (req, res) => {
  const db = getDatabase();
  res.json(db.orders || []);
});

app.post('/api/orders', async (req, res) => {
  const db = getDatabase();
  const order = {
    id: `ORD-2026-${Math.floor(1000 + Math.random() * 9000)}`,
    ...req.body,
    status: 'Processing',
    createdAt: new Date().toISOString()
  };

  db.orders = db.orders || [];
  db.orders.unshift(order);
  saveDatabase(db);

  const targetEmail = db.settings?.email || 'sarakamdar26@gmail.com';
  const html = `
    <div style="font-family:sans-serif; max-width:600px; margin:auto; border:1px solid #fbcfe8; padding:24px; border-radius:12px; background:#fffaf5;">
      <h2 style="color:#be185d;">🌸 Order Placed: ${order.id}</h2>
      <p><strong>Customer:</strong> ${order.customer?.name} (${order.customer?.email})</p>
      <p><strong>Address:</strong> ${order.customer?.address}</p>
      <p><strong>Total:</strong> ₹${order.total}</p>
    </div>
  `;
  await sendStoreEmail(targetEmail, `🌸 New Order: ${order.id} (₹${order.total})`, html, db.settings);

  res.status(201).json(order);
});

app.patch('/api/orders/:id', (req, res) => {
  const db = getDatabase();
  const order = (db.orders || []).find(o => o.id === req.params.id);
  if (order) {
    if (req.body.status) order.status = req.body.status;
    saveDatabase(db);
    res.json({ success: true });
  } else {
    res.status(404).json({ error: 'Order not found' });
  }
});

app.get('/api/settings', (req, res) => {
  const db = getDatabase();
  res.json(db.settings || {});
});

app.put('/api/settings', (req, res) => {
  const db = getDatabase();
  db.settings = { ...db.settings, ...req.body };
  saveDatabase(db);
  res.json(db.settings);
});

app.post('/api/test-email', async (req, res) => {
  const db = getDatabase();
  const target = db.settings?.email || 'sarakamdar26@gmail.com';
  const result = await sendStoreEmail(
    target,
    '🌸 Test Email from The Bead Room by Pallas Backend',
    '<h2>Email Verification Successful!</h2><p>Your backend can send email notifications properly.</p>',
    db.settings
  );
  res.json(result);
});

app.post('/api/upload', (req, res) => {
  const { base64, fileName } = req.body;
  try {
    const ext = path.extname(fileName || '') || '.jpg';
    const cleanBase64 = base64.replace(/^data:image\/\w+;base64,/, '');
    const buffer = Buffer.from(cleanBase64, 'base64');
    const safeName = `upload-${Date.now()}-${Math.round(Math.random() * 1e6)}${ext}`;
    fs.writeFileSync(path.join(UPLOADS_DIR, safeName), buffer);
    res.json({ success: true, url: `/uploads/${safeName}` });
  } catch (err) {
    res.status(400).json({ error: 'Upload failed' });
  }
});

app.listen(PORT, () => {
  console.log(`🌸 The Bead Room by Pallas running on http://localhost:${PORT}`);
  console.log(`🎨 Admin portal on http://localhost:${PORT}/admin.html`);
});
