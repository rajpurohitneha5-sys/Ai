# Upload and test without Android Studio
1. Extract the ZIP.
2. Upload the entire `AI_Personal_App_Full_Package` folder contents to the repository's `main` branch (no branch creation).
3. Ensure GitHub Actions is enabled; use Actions -> Android APK Build -> Run workflow.
4. Download the `AI-debug-APK` artifact from the completed workflow.
5. Install on your Android phone (allow install from that source when prompted).
6. Before testing, deploy and configure a gateway. The current Android code expects an OpenAI-compatible gateway URL and token.
7. Record errors/screenshots and send them for fixes.

Do not commit secrets, API keys, signing keys, or personal tokens into GitHub.
