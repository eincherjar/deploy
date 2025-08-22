interaktywny instalator i konfigurator środowiska uWSGI + Supervisor + Certbot dla aplikacji webowych (np. Django).
Skrypt prowadzi użytkownika krok po kroku przez:

instalację certyfikatu SSL (Let's Encrypt),

stworzenie pliku konfiguracyjnego dla uWSGI,

otwarcie portu w firewallu (UFW),

stworzenie pliku konfiguracyjnego dla Supervisora,

uruchomienie aplikacji jako usługi.

🔍 Szczegółowe funkcje

Deklaracja kolorów – do wyświetlania kolorowych komunikatów w terminalu.

get_ip_address
Pobiera adres IP serwera (hostname -I | awk '{print $1}').

ensure_directory_exists
Tworzy katalog, jeśli nie istnieje.

check_port_open / open_port / close_port
Sprawdza, czy port jest otwarty w UFW, a jeśli nie, otwiera go (lub zamyka).

install_certbot / get_ssl_certificate

Instaluje Certbota (klient Let's Encrypt).

Pyta o domenę i uruchamia Certbota w trybie --standalone, aby uzyskać certyfikat SSL.

create_config – główna funkcja:

Pyta, czy zainstalować Certbota i czy uzyskać certyfikat.

Instaluje uWSGI (przez pip) i supervisor (przez apt).

Pyta użytkownika o:

nazwę aplikacji,

adres IP serwera,

port (domyślnie 8000),

nazwę modułu WSGI (domyślnie core.wsgi:application),

ścieżkę do wirtualnego środowiska (albo "NO" jeśli brak).

Tworzy katalog deploy/ na logi i konfigurację.

Generuje plik uwsgi.ini z konfiguracją HTTPS (z wykorzystaniem certyfikatów z Let’s Encrypt).

Wyświetla instrukcje, jakie linie dodać do settings.py i urls.py w Django, żeby statiki/media działały.

Tworzy konfigurację Supervisora, aby uWSGI działało jako usługa.

Kopiuje plik supervisora do /etc/supervisor/conf.d/, wykonuje supervisorctl reread && supervisorctl update.

configure_supervisor
Generuje plik konfiguracyjny dla Supervisora (app_name.conf) i umieszcza go w /etc/supervisor/conf.d/.
Dzięki temu Supervisor automatycznie uruchamia i restartuje uWSGI dla aplikacji.

Menu główne
Po uruchomieniu skryptu użytkownik widzi opcje:

1 – Stwórz konfigurację uWSGI,

2 – Usuń konfigurację uWSGI (funkcja delete_config nie jest jednak zaimplementowana w tym skrypcie),

3 – Wyjście.

Uruchom skrypt:
```bash
chmod +x deploy.sh && ./deploy.sh
