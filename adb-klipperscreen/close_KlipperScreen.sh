#!/bin/bash
adbd() {
    docker exec adbd adb "$@"
}

# Parar o servidor de câmera do Octo4a
echo "Stopping Octo4a Camera Server..."
adbd shell su -c 'am stop-service com.octo4a/.camera.CameraService'

if adbd shell su -c 'pm list packages' | grep -i "x.org.server"; then
    adbd shell su -c "am force-stop x.org.server"
    adbd shell su -c "pkill -f 'x.org.server'"
fi

adbd shell su -c "input keyevent KEYCODE_POWER"  # Garante que a tela está desligada
adbd shell su -c "cmd window dismiss-keyguard"  # Remove keyguard (se necessário)
adbd shell su -c "input keyevent KEYCODE_SLEEP"  # Bloqueia dispositivo
adbd shell su -c "input swipe 300 1000 300 500"  # Gesture adicional para garantir bloqueio