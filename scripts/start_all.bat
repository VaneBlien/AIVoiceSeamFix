@echo off
echo Starting AIVoiceSeamFix...

echo [1/2] Starting Julia backend...
start "Julia Backend" cmd /c "cd /d F:\TTS\wave_filter\AIVoiceSeamFix && julia --project=julia julia/server.jl"

echo Waiting for backend to start...
timeout /t 5 /nobreak >nul

echo [2/2] Starting Python GUI...
cd /d F:\TTS\wave_filter\AIVoiceSeamFix\gui
call .venv\Scripts\activate
python main.py

pause