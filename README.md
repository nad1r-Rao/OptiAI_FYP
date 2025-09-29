🥽 OptiAI Glasses

AI-powered smart glasses for hands-free assistance

OptiAI Glasses is a wearable system that integrates ESP32-based smart glasses with a Flutter mobile app and a custom AI backend. The device enables real-time object recognition, voice interaction, and knowledge retrieval — designed to assist both visually impaired users and general users seeking a hands-free AI companion.

✨ Features

🎙️ Voice Commands – Hands-free speech-to-text and response via onboard microphone & speaker.

👁️ Real-Time Object Recognition – ESP32 camera + AI-powered object detection.

🤖 Custom LLM Integration – Hybrid system using a local model (for fast responses) + cloud API (for complex queries).

📚 RAG System – Retrieval-Augmented Generation for accurate object-related queries.

📱 Flutter Mobile App – Companion app for controlling settings, viewing logs, and managing data.

🔐 Firebase Integration – User authentication, query logging, and cloud data sync.

🌗 Light/Dark Mode – Seamless UI toggle in the mobile app.

🛠️ Tech Stack
Hardware

ESP32 (camera, microphone, speaker)

Smart glasses frame with embedded components

Software

Mobile App: Flutter + Dart

Backend: Node.js + Firebase

AI Models:

Speech-to-Text (STT)

Custom LLM (local + cloud integration)

Object Detection Model

Cloud: Firebase (Auth, Firestore, Storage)

📐 System Architecture
flowchart LR
  User((User)) -->|Voice / Camera| ESP32
  ESP32 -->|Data| MobileApp
  MobileApp -->|Text/Image Query| AI_Backend
  AI_Backend -->|LLM + RAG| Response
  Response --> MobileApp
  MobileApp --> ESP32
  ESP32 -->|Audio Output| User

🚀 Getting Started
1. Clone the Repository
git clone https://github.com/your-username/OptiAI-Glasses.git
cd OptiAI-Glasses

2. Setup Flutter App

Install Flutter SDK: Flutter Install Guide

Install dependencies:

flutter pub get


Run the app:

flutter run

3. Configure ESP32

Flash ESP32 with esp32_firmware/ code.

Update Wi-Fi credentials in env.h.

Upload using Arduino IDE or PlatformIO.

4. Firebase Setup

Create a Firebase project.

Enable Authentication and Firestore Database.

Add your Firebase config in env.dart.

📸 Demo Screenshots

(Add screenshots here – app UI, glasses prototype, object detection results)

📊 Roadmap

 Add multi-language speech support

 Improve real-time latency with edge processing

 Expand RAG system with custom datasets

 Release hardware assembly guide

🤝 Contributing

Contributions are welcome! Please fork the repo and submit a pull request.

📜 License

MIT License © 2025 Nadir R
