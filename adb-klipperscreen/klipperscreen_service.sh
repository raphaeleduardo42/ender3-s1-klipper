#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export DEBIAN_FRONTEND=noninteractive

SERVICE_LOG="/var/log/klipperscreen_service.log"
TMUX_SESSION="klipperscreen"

function log {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$SERVICE_LOG"
}

function adb_command {
    log "Executando: adb $*"
    if ! adb "$@" >> "$SERVICE_LOG" 2>&1; then
        log "Falha no comando: adb $*"
        return 1
    fi
    return 0
}

function is_screen_on {
    adb_command shell "dumpsys power | grep -q 'mWakefulness=Awake'"
    [ $? -eq 0 ] && echo "on" || echo "off"
}

function is_locked {
    adb_command shell "dumpsys window | grep -q 'mShowingLockscreen=true'"
    [ $? -eq 0 ] && echo "locked" || echo "unlocked"
}

case "$1" in
  start)
    log "---------- Iniciando Serviço ----------"
    
    # Reset ADB server
    adb kill-server >> "$SERVICE_LOG" 2>&1
    adb start-server >> "$SERVICE_LOG" 2>&1

    # Port forwarding
    adb_command forward tcp:6100 tcp:6003
    
    # Gerenciamento de estado da tela
    SCREEN_STATE=$(is_screen_on)
    LOCK_STATE=$(is_locked)
    
    log "Estado Inicial | Tela: $SCREEN_STATE | Bloqueio: $LOCK_STATE"

    if [[ "$SCREEN_STATE" == "off" ]]; then
        adb_command shell input keyevent 26
        sleep 2
        log "Tela ligada via ADB"
    fi

    if [[ "$LOCK_STATE" == "locked" ]]; then
        log "Iniciando sequência de desbloqueio..."
        adb_command shell input keyevent 82
        sleep 1
        adb_command shell input swipe 300 1000 300 500
        sleep 1
        log "Desbloqueio concluído"
    fi

    # Iniciar aplicativo
    adb_command shell am start-activity x.org.server/.MainActivity
    
    # Iniciar KlipperScreen
    log "Iniciando sessão tmux..."
    su orangepi -c "tmux new-session -d -s $TMUX_SESSION -n klipperscreen \
        'export DISPLAY=:100 && \
        source /home/orangepi/.KlipperScreen-env/bin/activate && \
        python3 /home/orangepi/KlipperScreen/screen.py'"
    
    log "Serviço iniciado com sucesso"
    ;;

  stop)
    log "---------- Parando Serviço ----------"
    
    # Parar KlipperScreen
    log "Encerrando sessão tmux..."
    su orangepi -c "tmux kill-session -t $TMUX_SESSION" >> "$SERVICE_LOG" 2>&1
    
    # Gerenciamento de estado da tela
    if [[ $(is_screen_on) == "on" ]]; then
        log "Desligando tela..."
        adb_command shell input keyevent 26
        sleep 1
        adb_command shell input keyevent 223
    fi
    
    log "Serviço parado com sucesso"
    ;;

  *)
    echo "Uso: $0 {start|stop}"
    exit 1
    ;;
esac

exit 0