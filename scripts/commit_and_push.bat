@echo off
rem Simple helper to commit and push changes. Update REMOTE and BRANCH accordingly.
set REMOTE=origin
set BRANCH=main
git init
git add .
git commit -m "Add MSNR bot scaffold"
echo Configure remote and credentials before pushing.
rem git remote add %REMOTE% <your-remote-url>
rem git push -u %REMOTE% %BRANCH%
echo Done.

echo To push to GitHub from this script, uncomment the REM lines and set your remote URL.

