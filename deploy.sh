#!/bin/bash

# Kolory
RESET="\033[0m"
BOLD="\033[1m"
RED="\033[31m"
LIGHT_BLUE="\033[34;1m"
LIGHT_GREEN="\033[32;1m"
ORANGE="\033[33;1m"
LIGHT_PURPLE="\033[35;1m"
LIGHT_GRAY="\033[37;1m"

# Funkcja do pobierania adresu IP
get_ip_address() {
    hostname -I | awk '{print $1}'
}

# Funkcja do tworzenia folderu, jeśli nie istnieje
ensure_directory_exists() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
    fi
}

# Funkcja do sprawdzania, czy port jest otwarty
check_port_open() {
    sudo ufw status | grep -w "$1" > /dev/null
}

# Funkcja do otwierania portu
open_port() {
    if ! check_port_open "$1"; then
        sudo ufw allow "$1"
        echo -e "${LIGHT_GREEN}Port $1 został otwarty.${RESET}"
    else
        echo -e "${LIGHT_GREEN}Port $1 jest już otwarty.${RESET}"
    fi
}

# Funkcja do zamykania portu
close_port() {
    if check_port_open "$1"; then
        sudo ufw deny "$1"
        echo -e "${LIGHT_GREEN}Port $1 został zamknięty.${RESET}"
    else
        echo -e "${LIGHT_GREEN}Port $1 jest już zamknięty.${RESET}"
    fi
}

# Funkcja do instalacji Certbota
install_certbot() {
    echo -e "${LIGHT_BLUE}Instalowanie Certbota...${RESET}"
    sudo apt update
    sudo apt install -y certbot
}

# Funkcja do uzyskiwania certyfikatu
get_ssl_certificate() {
    read -p "$(echo -e "${LIGHT_GREEN}Wprowadź nazwę domeny (np. b2b.globetyre.pl): ${RESET}") " domain_name
    echo -e "${LIGHT_BLUE}Uzyskiwanie certyfikatu SSL dla domeny: $domain_name${RESET}"
    sudo certbot certonly --standalone -d "$domain_name"
}

# Funkcja do tworzenia pliku konfiguracyjnego uWSGI
create_config() {
    pip install uWSGI
    sudo apt install supervisor
    
    echo -e "${LIGHT_BLUE}Tworzenie pliku konfiguracyjnego uWSGI${RESET}"

    project_name=$(basename "$(pwd)")
    read -p "$(echo -e "${LIGHT_GREEN}Wprowadź nazwę aplikacji (lub naciśnij Enter, aby użyć${RESET} ${LIGHT_BLUE}$project_name${RESET}): ")" app_name
    app_name=${app_name:-$project_name}

    ip_address=$(get_ip_address)
    read -p "$(echo -e "${LIGHT_GREEN}Wprowadź adres IP serwera (lub naciśnij Enter, aby użyć${RESET} ${LIGHT_BLUE}$ip_address${RESET}): ")" server_ip
    server_ip=${server_ip:-$ip_address}

    read -p "$(echo -e "${LIGHT_GREEN}Wprowadź port (lub naciśnij Enter, aby użyć${RESET} ${LIGHT_BLUE}8000${RESET}): ")" server_port
    server_port=${server_port:-8000}

    open_port "$server_port"

    default_module_name="core"
    read -p "$(echo -e "${LIGHT_GREEN}Wprowadź nazwę modułu WSGI (lub naciśnij Enter, aby użyć${RESET} ${LIGHT_BLUE}$default_module_name${RESET}): ")" module_name
    module_name=${module_name:-$default_module_name}
    module_path="${module_name}.wsgi:application"

    current_dir=$(pwd)
    default_venv_path="${current_dir}/.env"
    read -p "$(echo -e "${LIGHT_GREEN}Wprowadź ścieżkę do folderu z wirtualnym środowiskiem (lub wpisz NO, jeśli nie używasz venv, lub naciśnij Enter, aby użyć${RESET} ${LIGHT_BLUE}${default_venv_path}${RESET}): ")" venv_folder

    if [[ "$venv_folder" == "NO" ]]; then
        venv_path=""
    elif [[ -z "$venv_folder" ]]; then
        venv_path="${default_venv_path}"
    else
        venv_path="${venv_folder}"
    fi

    static_path="${current_dir}/static"
    media_path="${current_dir}/media"
    log_dir="${current_dir}/deploy"

    ensure_directory_exists "$log_dir"

    # Dodaj konfigurację SSL
    ssl_certificate="/etc/letsencrypt/live/$domain_name/fullchain.pem"
    ssl_key="/etc/letsencrypt/live/$domain_name/privkey.pem"

    uwsgi_conf_content="[uwsgi]
module = ${module_path}
https = ${server_ip}:${server_port},${ssl_certificate},${ssl_key}
chdir = ${current_dir}
home = ${venv_path}
static-map = /static=${static_path}
static-map = /media=${media_path}
processes = 4
threads = 2
master = true
vacuum = true
logto = ${log_dir}/uwsgi.log
"

    uwsgi_conf_path="${log_dir}/uwsgi.ini"

    echo "$uwsgi_conf_content" > "$uwsgi_conf_path"

    echo -e "Plik konfiguracyjny ${LIGHT_GREEN}uWSGI${RESET} został utworzony: ${LIGHT_BLUE}$uwsgi_conf_path${RESET}"

    echo -e "Aby uruchomić ${LIGHT_GREEN}uWSGI${RESET}, użyj poniższej komendy: ${LIGHT_PURPLE}uwsgi --ini $uwsgi_conf_path${RESET}"

    echo -e "${LIGHT_BLUE}Pamiętaj, aby dodać poniższe linie do pliku settings.py po liniach:${RESET}"
    echo "STATIC_URL = '/static/'"
    echo "MEDIA_URL = '/media/'"
    echo ""
    echo -e "${BOLD}MEDIA_ROOT = os.path.join(BASE_DIR, 'media')${RESET}"
    echo -e "${BOLD}STATIC_ROOT = os.path.join(BASE_DIR, 'static')${RESET}"
    echo ""
    echo -e "${LIGHT_BLUE}Pamiętaj, aby dodać poniższe linie do pliku urls.py:${RESET}"
    echo "if settings.DEBUG:"
    echo "    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)"
    echo "    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)"
    echo ""
    echo -e "Następnie wykonaj komendę: ${LIGHT_GREEN}python3 manage.py collectstatic ${RESET}"

    # Konfiguracja Supervisora
    configure_supervisor
    
    echo -e "Aby zrestartować aplikację, użyj komendy: ${LIGHT_GREEN}sudo supervisorctl restart ${app_name}${RESET}"
}

# Funkcja do konfiguracji Supervisora
configure_supervisor() {
    if [ ! -f "$uwsgi_conf_path" ]; then
        echo -e "${RED}Plik konfiguracyjny uWSGI nie istnieje. Najpierw stwórz konfigurację.${RESET}"
        return
    fi

    supervisor_conf_content="[program:${app_name}]
command=uwsgi --ini ${uwsgi_conf_path}
directory=${current_dir}
autostart=true
autorestart=true
stderr_logfile=${log_dir}/uwsgi.err.log
stdout_logfile=${log_dir}/uwsgi.out.log
user=$(whoami)
environment=PATH=\"${venv_path}/bin\""

    supervisor_conf_path="${log_dir}/${app_name}.conf"
    echo "$supervisor_conf_content" > "$supervisor_conf_path"

    echo -e "Plik konfiguracyjny Supervisora został utworzony: ${LIGHT_BLUE}$supervisor_conf_path${RESET}"

    sudo cp "$supervisor_conf_path" /etc/supervisor/conf.d/
    sudo supervisorctl reread
    sudo supervisorctl update
    echo -e "${LIGHT_GREEN}Supervisor został skonfigurowany.${RESET}"
}

# Funkcja obsługująca wybór menu
handle_menu_choice() {
    case "$1" in
        1) create_config ;;
        2) delete_config ;;
        3) exit 0 ;;
        *) echo -e "${RED}Nieprawidłowy wybór. Wybierz 1, 2, lub 3.${RESET}" ;;
    esac
}

# Wyświetlanie menu
echo -e "${LIGHT_BLUE}Wybierz opcję:${RESET}"
echo "1. Stwórz konfigurację uWSGI"
echo "2. Usuń konfigurację uWSGI"
echo "3. Wyjście"

# Opcja do instalacji Certbota
read -p "$(echo -e "${LIGHT_GREEN}Czy chcesz zainstalować Certbota? (tak/nie lub TAK/NIE): ${RESET}") " install_certbot_choice

# Akceptacja różnych wariantów odpowiedzi
if [[ "$install_certbot_choice" =~ ^[Tt]ak$ || "$install_certbot_choice" =~ ^[Tt][Aa][Kk]$ ]]; then
    install_certbot
    get_ssl_certificate
fi

read -p "Wybór: " choice
handle_menu_choice "$choice"
