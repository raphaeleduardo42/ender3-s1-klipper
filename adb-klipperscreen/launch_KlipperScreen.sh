#!/bin/bash
adbd() {
    docker exec adbd adb "$@"
}

# forward local display :100 to remote display :0
adbd forward tcp:6100 tcp:6003

adbd shell su -c 'dumpsys window 2>/dev/null' | grep -E 'mDreamingLockscreen=true|isStatusBarKeyguard=true' > /dev/null 2>&1

if [ $? -lt 1 ]; then
    echo "Screen is OFF and Locked. Turning screen on..."
    adbd shell su -c "input keyevent KEYCODE_WAKEUP"
fi


adbd shell su -c 'dumpsys window 2>/dev/null' | grep -E 'mDreamingLockscreen=true|isStatusBarKeyguard=true' > /dev/null 2>&1

if [ $? -lt 1 ]; then
    echo "Screen is Locked. Unlocking..."
    
    # Sequência completa de desbloqueio
    adbd shell su -c "input keyevent KEYCODE_WAKEUP"  # Garante que a tela está ligada
    adbd shell su -c "input keyevent 66"              # KEYCODE_ENTER (para padrões simples)
    adbd shell su -c "input swipe 300 1000 300 500"   # Swipe para deslizar o cadeado
    adbd shell su -c "wm dismiss-keyguard"            # Remove a tela de bloqueio
fi

# Iniciar o servidor de câmera do Octo4a
echo "Starting Octo4a Camera Server..."
adbd shell su -c 'am start-service com.octo4a/.camera.CameraService'

# start xsdl
adbd shell su -c 'am start -n "x.org.server/.MainActivity"'

attempt=1
max_attempts=10

while [ $attempt -le $max_attempts ]; do
    if adbd shell su -c 'netstat -an | grep -q "0.0.0.0:6003"'; then
        echo "X server listening on port 6003."
        break
    else
        echo "Attempt $attempt: X not started. Waiting..."
        attempt=$((attempt + 1))
        sleep 5
    fi
done

export DISPLAY=:100
source "/home/orangepi/.KlipperScreen-env/bin/activate"
python3 "/home/orangepi/KlipperScreen/screen.py"