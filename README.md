# 🏥 Pharmacy POS (Point of Sale)

A comprehensive, mobile-first POS system designed specifically for pharmacies. This application helps pharmacy owners track inventory, manage sales, monitor profits, and stay informed about expired medications and low stock levels.

## 🚀 Key Features

### 🛒 Point of Sale (POS)
- **Barcode Scanning:** Fast product checkout using the device's camera.
- **OCR (Optical Character Recognition):** Intelligent text recognition for identifying products from labels and packaging.
- **Voice Search:** Hands-free product search using Speech-to-Text.
- **Real-time Inventory Check:** Automatic alerts if an item is out of stock during checkout.
- **Flexible Payments:** Support for multiple units (Strip vs. Piece) and real-time total calculation.

### 📦 Inventory Management
- **Stock Tracking:** Monitor current stock levels for all medications.
- **Expiring Soon Alerts:** Dedicated dashboard for tracking medications near their expiration date.
- **Low Stock Alerts:** Automated warnings when stock levels fall below a set threshold.
- **Bulk Import:** Support for importing product data via Excel and CSV files.
- **Stock In/Returns:** Manage new arrivals and returned items efficiently.

### 📊 Business Intelligence & Reporting
- **Sales Reports:** Detailed analysis of daily, weekly, and monthly sales performance.
- **Profit Tracking:** Real-time profit calculation based on purchase and sale prices.
- **Top Products:** Identify best-selling medications at a glance.
- **Visual Charts:** Interactive charts (using `fl_chart`) for better data visualization.

### 🔐 Security & Administration
- **Admin Authentication:** Secure login for owners and managers.
- **Google Sign-In:** Easy access via Google accounts.
- **User Roles:** Protected admin dashboard for sensitive business data.

## 🛠️ Tech Stack

- **Frontend:** [Flutter](https://flutter.dev/) (3.10.8+)
- **State Management:** [Provider](https://pub.dev/packages/provider)
- **Database:** [SQFlite](https://pub.dev/packages/sqflite) (Local persistence)
- **Machine Learning:** [Google ML Kit](https://developers.google.com/ml-kit) (Text Recognition)
- **OCR & Vision:** `google_mlkit_text_recognition`
- **Voice Interaction:** `speech_to_text`
- **UI Components:** `lucide_icons`, `fl_chart`, `google_fonts`
- **Data Handling:** `excel`, `csv`, `pdf`, `printing`

## 📁 Project Structure

```text
lib/
├── config/       # Application configuration & API endpoints
├── models/       # Data models (Product, SaleRecord, etc.)
├── providers/    # State management (Admin, POS)
├── screens/      # Main UI screens (Home, Admin Dashboard, etc.)
├── services/     # Logic for OCR, Speech, Database, and Exporting
├── utils/        # Constants, colors, and helpers
└── widgets/      # Reusable UI components
```

## ⚙️ Installation & Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/mhshadin/Pharamacy_POS.git
   cd Pharmacy_POS
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Database Setup:**
   - The app uses **SQFlite** for local storage. No external DB setup is required for the mobile app.
   - For backend integration, refer to the SQL schema in `backend/digitalbay_pharmapos.sql`.

4. **Run the application:**
   ```bash
   flutter run
   ```

## 📸 Screenshots

*(Add your screenshots here)*

## 📄 License

This project is proprietary. Contact the repository owner for licensing information.

---
Developed with ❤️ for Pharmacy Management.
