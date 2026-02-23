{
    :put "--- Starlink-MikroTik Professional Setup Wizard ---"
    
    # دریافت تنظیمات وایرلس
    :local ssid [:terminal get-value name="SSID (e.g. Irancell-4G): "]
    :local wlapass [:terminal get-value name="Wireless Password (min 8 chars): "]
    
    # دریافت تنظیمات VPN
    :local ipsecsec [:terminal get-value name="IPsec Pre-Shared Key: "]
    :local usercount [:toint [:terminal get-value name="How many VPN users do you want to create? "]]
    
    :put "Configuring System..."

    # ۱. تنظیم اینترنت و NAT
    /ip dhcp-client add interface=ether1 disabled=no use-peer-dns=yes add-default-route=yes
    /ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade comment="Main-Internet-NAT"

    # ۲. فایروال ورودی (امنیت کامل)
    /ip firewall filter
    add chain=input connection-state=established,related action=accept
    add chain=input protocol=icmp action=accept
    add chain=input protocol=udp dst-port=500,1701,4500 action=accept
    add chain=input in-interface=!ether1 action=accept
    add chain=input action=drop

    # ۳. وایرلس و امنیت
    /interface wireless security-profiles add name=Wlan_Profile mode=dynamic-keys authentication-types=wpa2-psk unicast-ciphers=aes-ccm group-ciphers=aes-ccm wpa2-pre-shared-key=$wlapass
    /interface wireless set [ find default-name=wlan1 ] ssid=$ssid security-profile=Wlan_Profile mode=ap-bridge wps-mode=disabled disabled=no

    # ۴. شبکه داخلی و DNS
    /ip address add address=192.168.10.1/24 interface=wlan1
    /ip pool add name=wlan-pool ranges=192.168.10.10-192.168.10.100
    /ip dhcp-server add name=dhcp-wlan interface=wlan1 address-pool=wlan-pool disabled=no
    /ip dhcp-server network add address=192.168.10.0/24 dns-server=192.168.10.1

    # ۵. استارلینک
    /ip address add address=192.168.100.2/24 interface=ether1
    /ip firewall nat add chain=srcnat dst-address=192.168.100.1 action=masquerade

    # ۶. بلاک لیست ایران
    /ip firewall address-list add list=IRAN_IPs address=185.0.0.0/8
    /ip firewall filter add chain=forward dst-address-list=IRAN_IPs action=drop

    # ۷. تنظیمات پروفایل VPN
    /ip pool add name=vpn-pool ranges=172.16.0.10-172.16.0.50
    /ppp profile add name=vpn-profile local-address=172.16.0.1 remote-address=vpn-pool use-encryption=yes dns-server=8.8.8.8,1.1.1.1
    /interface l2tp-server server set enabled=yes default-profile=vpn-profile use-ipsec=required ipsec-secret=$ipsecsec
    /ip firewall nat add chain=srcnat src-address=172.16.0.0/24 action=masquerade

    # ۸. ایجاد کاربران به صورت تعاملی
    :for i from=1 to=$usercount do={
        :local uname [:terminal get-value name="Enter Name for User $i: "]
        :local upass [:terminal get-value name="Enter Password for User $i: "]
        /ppp secret add name=$uname password=$upass profile=vpn-profile
    }

    # ۹. اسکریپت آپدیت خودکار
    /system script add name=UpdateIranIPs source={ /tool fetch url="https://github.com/herrbischoff/country-ip-blocks/raw/master/ipv4/ir.cidr" dst-path=ir.cidr; :local content [/file get ir.cidr contents]; /ip firewall address-list remove [find list=IRAN_IPs]; :foreach line in=[:toarray $content] do={ :if ([:len $line] > 8) do={ /ip firewall address-list add list=IRAN_IPs address=$line } }; /file remove ir.cidr }
    /system scheduler add name=Schedule_Update_IR_IP interval=7d on-event=UpdateIranIPs start-time=03:00:00
    /system scheduler add name=Run_Update_On_Startup on-event=UpdateIranIPs start-time=startup

    # ۱۰. بستن سرویس‌های اضافه
    /ip service set telnet,ftp,api,api-ssl disabled=yes

    :put "!!! SETUP COMPLETED SUCCESSFULLY !!!"
}