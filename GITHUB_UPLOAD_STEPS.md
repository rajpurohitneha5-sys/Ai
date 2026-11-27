# Upload AI project to your separate GitHub repository

1. Extract `AI_Personal_App_Merged.zip` on your computer.
2. Install Android Studio and open the extracted `AI_Personal_App_Merged` folder (the project root, not its `android` subfolder). Android Studio may prompt to install SDK components; allow it.
3. Wait for Gradle sync. If sync/build fails, fix that before treating the project as working. This source bundle currently has no Gradle wrapper, so Android Studio/Gradle setup may be needed.
4. Create/open your **separate AI GitHub repository** in GitHub (not the Jai Malhar repository).
5. On GitHub, use **Add file → Upload files**. For folder structure, easiest is Git locally: install Git, open a terminal in the extracted folder, and run:

   ```bash
   git init
   git add .
   git commit -m "Initial merged AI Android foundation"
   git branch -M main
   git remote add origin https://github.com/YOUR-USERNAME/YOUR-AI-REPO.git
   git push -u origin main
   ```

6. Replace the remote URL with your AI repository URL. If the GitHub repository already contains a README or other commit, first reconcile it (clone the repo and copy the project files into that clone) rather than force-pushing.
7. Never add `.env` files, provider secrets, OAuth secrets, signing keys, or private data to Git. Only commit `.env.example` placeholders.
8. After upload, open the repository and confirm the `android/`, `backend/`, and `docs/` folders and their files are present.

This upload is for the AI project only. Do not use the connected Jai Malhar Git repository.
