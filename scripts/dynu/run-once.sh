# Bootstrap: this copies the scripts to the correct locations and enables the services
set -euo pipefail

# Flow summary:
# copy files
# daemon-reload
# edit config
# enable + start timer
# done

sudo mkdir -p /etc/conf.d
sudo install -m 755 ip-monitor.sh /usr/local/bin/ip-monitor.sh
sudo cp dynu.service /etc/systemd/system/dynu.service
sudo cp dynu.timer /etc/systemd/system/dynu.timer
sudo cp dynu-environment /etc/conf.d/dynu-environment

sudo systemctl daemon-reload

echo "Configure Dynu credentials..."
sudo ${EDITOR:-vi} /etc/conf.d/dynu-environment

sudo chmod 600 /etc/conf.d/dynu-environment
sudo chown root:root /etc/conf.d/dynu-environment


sudo systemctl enable dynu.timer
sudo systemctl start dynu.timer

echo "Done!"
echo "Last IP: "
echo "Use: journalctl -u dynu.service -f"
