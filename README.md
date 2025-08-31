0) Obiettivi e naming (blue-green)

Backend (DRF): gira su porta interna 9001 dietro Nginx.

Frontend (Hugo): statici in /var/www/djungo2 serviti da Nginx sotto /djungo2/.

API nuove raggiungibili da Nginx sotto /api2/ → proxy a 127.0.0.1:9001.

Ambienti: niente sovrascrittura di variabili tra locale e server; usare .env dedicato sul server.

1) Preparazione server (una volta sola)
# sul server
apt update && apt -y install git curl build-essential ufw python3-pip python3-venv nginx
ufw allow OpenSSH
ufw allow 80
ufw allow 443
ufw --force enable

2) Struttura cartelle (nuovo “green”)
# sul server
mkdir -p /opt/djungo2/app
mkdir -p /opt/djungo2/run
mkdir -p /opt/djungo2/log
chown -R root:root /opt/djungo2

3) Trasferimento progetto (scegline uno)
A) Da Git (consigliato)
# sul server
cd /opt/djungo2/app
git clone GIT_REPO_URL .
git checkout BRANCH_VERDE   # es. main, staging, release/x.y

B) Da locale con rsync
# sul tuo PC
rsync -avz --delete --exclude '.venv' --exclude '.git' ./PERCORSO_PROGETTO/ root@65.21.176.227:/opt/djungo2/app/

4) Virtualenv + dipendenze
# sul server
cd /opt/djungo2/app
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip wheel
pip install -r requirements.txt

5) Variabili d’ambiente (separate!)

Crea un file solo sul server: /opt/djungo2/app/.env (non committarlo).

# sul server
nano /opt/djungo2/app/.env


Esempio (adatta):

DJANGO_SETTINGS_MODULE=yourproject.settings.production
SECRET_KEY=***metti-chiave-server***
DEBUG=False
ALLOWED_HOSTS=65.21.176.227,example.com
DATABASE_URL=postgres://USER:PASS@HOST:5432/DBNAME
# qualsiasi altro valore (email, cache, storage, ecc.)


Permessi:

chmod 600 /opt/djungo2/app/.env

6) Migrazioni + statici (prima accensione)
# sul server
cd /opt/djungo2/app
source .venv/bin/activate
# Assicura che Django legga .env (via python-dotenv o settings dedicati)
python manage.py migrate --noinput
python manage.py collectstatic --noinput

7) Gunicorn come service systemd

Crea /etc/systemd/system/djungo2.service

nano /etc/systemd/system/djungo2.service


Contenuto:

[Unit]
Description=Djungō DRF (green) via Gunicorn
After=network.target

[Service]
User=root
WorkingDirectory=/opt/djungo2/app
EnvironmentFile=/opt/djungo2/app/.env
ExecStart=/opt/djungo2/app/.venv/bin/gunicorn yourproject.wsgi:application \
  --bind 127.0.0.1:9001 \
  --workers 3 \
  --timeout 60 \
  --access-logfile /opt/djungo2/log/gunicorn_access.log \
  --error-logfile /opt/djungo2/log/gunicorn_error.log \
  --pid /opt/djungo2/run/gunicorn.pid
Restart=always

[Install]
WantedBy=multi-user.target


Attiva e avvia:

systemctl daemon-reload
systemctl enable djungo2
systemctl start djungo2
systemctl status djungo2 --no-pager


Test backend localmente:

curl -I http://127.0.0.1:9001/  # 200/301/302 OK

8) Hugo build e pubblicazione

Sul tuo repo Hugo (locale o server):

# build (locale)
hugo --minify
# trasferisci sul server
rsync -avz ./public/ root@65.21.176.227:/var/www/djungo2/
# oppure buildare direttamente sul server se hai i sorgenti


Permessi:

# sul server
mkdir -p /var/www/djungo2
chown -R www-data:www-data /var/www/djungo2

9) Nginx (reverse proxy + statici)

Crea /etc/nginx/sites-available/djungo2.conf

nano /etc/nginx/sites-available/djungo2.conf


Contenuto (HTTP per test; HTTPS dopo):

server {
    listen 80;
    server_name 65.21.176.227;  # aggiungi dominio quando pronto

    # Hugo static under /djungo2/
    location /djungo2/ {
        alias /var/www/djungo2/;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    # Django API under /api2/
    location /api2/ {
        proxy_pass         http://127.0.0.1:9001/;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        client_max_body_size 20m;
    }

    # (opzionale) media/static dedicati, se serviti da Nginx
    # location /static/ { alias /opt/djungo2/app/static/; }
    # location /media/  { alias /opt/djungo2/app/media/;  }

    # sicurezza base
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-Content-Type-Options nosniff;
    add_header Referrer-Policy strict-origin-when-cross-origin;
    add_header X-XSS-Protection "1; mode=block";
}


Abilita e riavvia:

ln -s /etc/nginx/sites-available/djungo2.conf /etc/nginx/sites-enabled/djungo2.conf
nginx -t && systemctl reload nginx


Smoke test da fuori:

http://65.21.176.227/djungo2/ → deve servire Hugo.

http://65.21.176.227/api2/ → deve rispondere DRF (es. /api2/health/ se l’hai).

10) Healthcheck semplice (consigliato)

Aggiungi una view DRF/URL /health/ che ritorna {"ok": true}.
Serve per monitor e per GitHub Actions post-deploy.

11) Logrotate (facoltativo ma utile)
nano /etc/logrotate.d/djungo2


Contenuto:

/opt/djungo2/log/*.log {
    daily
    rotate 14
    compress
    missingok
    notifempty
    copytruncate
}

12) Hardening quando tutto è ok
# sul server (solo dopo aver verificato l’accesso con chiave!)
sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart ssh


In Nginx, passa a HTTPS (dopo test):

apt -y install certbot python3-certbot-nginx
certbot --nginx -d TUO_DOMINIO   # aggiungerà i blocchi 443

13) GitHub Action (step successivo)

Workflow che fa:

build/test,

rsync/ssh su /opt/djungo2/app,

pip install -r requirements.txt,

migrate, collectstatic,

systemctl restart djungo2,

healthcheck /api2/health/.

Segreti: usa GitHub Secrets (SSH key di deploy limitata, non quella personale).

Criticità che abbiamo già visto (e come evitarle)

Chiavi SSH: esegui comandi SSH dal PC, non dal server; ~/.ssh/config locale con IdentitiesOnly yes.

sshd_config: controlla gli override in sshd_config.d; verifica sempre con sshd -T.

Permessi: .env (600), .ssh (700) e authorized_keys (600).

Nginx: ricorda il prefisso /api2/ nel proxy_pass (trailing slash importante).

Blue-green: lascia in piedi il vecchio stack finché /api2/ e /djungo2/ non sono verificati; quando promuovi “green”, prepara il prossimo “blue”.

Se vuoi, nel prossimo messaggio ti preparo:

un unit test/healthcheck Django minimale,

un server block Nginx già pronto per HTTPS con dominio,

e un workflow GitHub Actions d’esempio per rsync + restart + healthcheck.
