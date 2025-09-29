# 🥽 OptiAI Glasses

**AI-powered smart glasses for hands-free assistance**

OptiAI Glasses is a wearable system that integrates **ESP32-based smart glasses** with a **Flutter mobile app** and a **custom AI backend**.
The device enables **real-time object recognition, voice interaction, and knowledge retrieval** — designed to assist both visually impaired users and general users seeking a hands-free AI companion.

---

## ✨ Features

* 🎙️ **Voice Commands** – Hands-free speech-to-text and response via onboard microphone & speaker.
* 👁️ **Real-Time Object Recognition** – ESP32 camera + AI-powered object detection.
* 🤖 **LLM Integration** – Hybrid system using a local model (for fast responses) + cloud API (for complex queries) + intent classifier model
* 📚 **RAG System** – Retrieval-Augmented Generation for accurate object-related queries.
* 📚 **Real-time info** – Retrieval of real time info as user asked.
* 📱 **Flutter Mobile App** – Companion app for controlling settings, viewing logs, and managing data.
* 🔐 **Firebase Integration** – User authentication, query logging, and cloud data sync.
* 🌗 **Light/Dark Mode** – Seamless UI toggle in the mobile app.

---

## 🛠️ Tech Stack

### Hardware

* ESP32 (camera, microphone, speaker)
* Smart glasses frame with embedded components

### Software

* **Mobile App:** Flutter + Dart
* **Backend:** Node.js + Firebase + python
* **AI Models:**

  * Classifier (text or image based queries)
  * Intent Classifier (for real time queries)
  * Custom LLM (local + cloud integration)
  
* **Cloud:** Firebase (Auth, Firestore, Storage)

---

## 📐 System Architecture

```mermaid
flowchart LR
  User((User)) -->|Voice / Camera| ESP32
  ESP32 -->|Data| MobileApp
  MobileApp -->|Text/Image Query| AI_Backend
  AI_Backend -->|LLM + RAG| Response
  Response --> MobileApp
  MobileApp --> ESP32
  ESP32 -->|Audio Output| User
```

---

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/nad1r-Rao/OptiAI_FYP.git
cd OptiAI_FYP
```

### 2. Setup Flutter App

* Install Flutter SDK → [Flutter Install Guide](https://docs.flutter.dev/get-started/install)
* Install dependencies:

  ```bash
  flutter pub get
  ```
* Run the app:

  ```bash
  flutter run
  ```

### 3. Configure ESP32

* Flash ESP32 with code in `/esp32_firmware/`
* Update Wi-Fi credentials in `env.h`
* Upload using **Arduino IDE** or **PlatformIO**

### 4. Firebase Setup

* Create a Firebase project
* Enable **Authentication** and **Firestore Database**
* Add your Firebase config in `env.dart`

---

## 📸 Demo Screenshots

*in progress...*

---

## 📊 Roadmap

* [ ] Add multi-language speech support
* [ ] Improve real-time latency with edge processing
* [ ] Expand RAG system with custom datasets
* [ ] Release hardware assembly guide

---

## 🤝 Contributing

Contributions are welcome! Please fork the repo and submit a pull request.

---

## 📜 License

MIT License © 2025 **Nadir R**
