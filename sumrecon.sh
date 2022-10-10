#!/bin/bash
    pwd=$PWD 

    url=$1 
    if [ ! -x "$(command -v assetfinder)" ]; then
        echo "[-] assetfinder required to run script"
        exit 1
    fi
    
    if [ ! -x "$(command -v amass)" ]; then
        echo "[-] amass required to run script"
        exit 1
    fi
    
    if [ ! -x "$(command -v sublist3r)" ]; then
        echo "[-] sublist3r required to run script"
        exit 1
    fi

 
    if [ ! -x "$(command -v httprobe)" ]; then
        echo "[-] httprobe required to run script"
        exit 1
    fi
    
    if [ ! -x "$(command -v waybackurls)" ]; then
        echo "[-] waybackurls required to run script"
        exit 1
    fi
    
    if [ ! -x "$(command -v whatweb)" ]; then
        echo "[-] whatweb required to run script"
        exit 1
    fi
    if [ ! -x "$(command -v waybackurls)" ]; then
        echo "[-] waybackurls required to run script"
        exit 1
    fi

    if [ ! -d "$pwd/$url" ];then
        mkdir $pwd/$url
    fi
    if [ ! -d "$pwd/$url/recon" ];then
        mkdir $pwd/$url/recon
    fi
    if [ ! -d "$pwd/$url/recon/3rd-lvls" ];then
        mkdir $pwd/$url/recon/3rd-lvls
    fi
    if [ ! -d "$pwd/$url/recon/scans" ];then
        mkdir $pwd/$url/recon/scans
    fi
    if [ ! -d "$pwd/$url/recon/httprobe" ];then
        mkdir $pwd/$url/recon/httprobe
    fi
    if [ ! -d "$pwd/$url/recon/potential_takeovers" ];then
        mkdir $pwd/$url/recon/potential_takeovers
    fi
    if [ ! -d "$pwd/$url/recon/wayback" ];then
        mkdir $pwd/$url/recon/wayback
    fi
    
    if [ ! -d "$pwd/$url/recon/wayback/params" ];then
        mkdir $pwd/$url/recon/wayback/params
    fi
    if [ ! -d "$pwd/$url/recon/wayback/extensions" ];then
        mkdir $pwd/$url/recon/wayback/extensions
    fi
    if [ ! -d "$pwd/$url/recon/whatweb" ];then
        mkdir $pwd/$url/recon/whatweb
    fi
    if [ ! -f "$pwd/$url/recon/httprobe/alive.txt" ];then
        touch $pwd/$url/recon/httprobe/alive.txt
    fi
    if [ ! -f "$pwd/$url/recon/final.txt" ];then
        touch $pwd/$url/recon/final.txt
    fi
    if [ ! -f "$pwd/$url/recon/3rd-lvl" ];then
        touch $pwd/$url/recon/3rd-lvl-domains.txt
    fi
    
    echo "[+] Harvesting subdomains with assetfinder..."
    assetfinder $url| grep '.'$url | sort -u | tee -a $pwd/$url/recon/final1.txt
    
    echo "[+] Double checking for subdomains with amass..."
    amass enum -passive -d $url | tee -a $pwd/$url/recon/final1.txt
    sort -u $pwd/$url/recon/final1.txt >> $pwd/$url/recon/final.txt
    rm $pwd/$url/recon/final1.txt
    
    echo "[+] Compiling 3rd lvl domains..."
    cat $pwd/$url/recon/final.txt | grep -Po '(\w+\.\w+\.\w+)$' | sort -u >> $pwd/$url/recon/3rd-lvl-domains.txt
    #write in line to recursively run thru final.txt
    for line in $(cat $pwd/$url/recon/3rd-lvl-domains.txt);do echo $line | sort -u | tee -a $pwd/$url/recon/final.txt;done
    
    echo "[+] Harvesting full 3rd lvl domains with sublist3r..."
    for domain in $(cat $pwd/$url/recon/3rd-lvl-domains.txt);do sublist3r -d $domain -o $pwd/$url/recon/3rd-lvls/$domain.txt;done
    cat $pwd/$url/recon/final.txt | sort -u >> $pwd/$url/recon/final2.txt
    rm $pwd/$url/recon/final.txt
    mv $pwd/$url/recon/final2.txt $pwd/$url/recon/final.txt
    echo "[+] Probing for alive domains..."
    cat $pwd/$url/recon/final.txt | sort -u | httprobe -s -p https:443 | sed 's/https\?:\/\///' | tr -d ':443' | sort -u >> $pwd/$url/recon/httprobe/a.txt
    sort -u $pwd/$url/recon/httprobe/a.txt > $pwd/$url/recon/httprobe/alive.txt
    echo "[+] Checking for possible subdomain takeover..."
    if [ ! -f "$pwd/$url/recon/potential_takeovers/domains.txt" ];then
        touch $pwd/$url/recon/potential_takeovers/domains.txt
    fi
    if [ ! -f "$pwd/$url/recon/potential_takeovers/potential_takeovers1.txt" ];then
        touch $pwd/$url/recon/potential_takeovers/potential_takeovers1.txt
    fi
    for line in $(cat $pwd/$url/recon/final.txt);do echo $line |sort -u >> $pwd/$url/recon/potential_takeovers/domains.txt;done
    subjack -w $pwd/$url/recon/httprobe/alive.txt -t 100 -timeout 30 -ssl -c ~/go/src/github.com/haccer/subjack/fingerprints.json -v 3 >> $pwd/$url/recon/potential_takeovers/potential_takeovers1.txt
    sort -u $pwd/$url/recon/potential_takeovers/potential_takeovers1.txt >> $pwd/$url/recon/potential_takeovers/potential_takeovers.txt
    rm $pwd/$url/recon/potential_takeovers/potential_takeovers1.txt
    
    echo "[+] Running whatweb on compiled domains..."
    for domain in $(cat $pwd/$url/recon/httprobe/alive.txt);do
        if [ ! -d  "$pwd/$url/recon/whatweb/$domain" ];then
            mkdir $pwd/$url/recon/whatweb/$domain
        fi
        if [ ! -d "$pwd/$url/recon/whatweb/$domain/output.txt" ];then
            touch $pwd/$url/recon/whatweb/$domain/output.txt
        fi
        if [ ! -d "$pwd/$url/recon/whaweb/$domain/plugins.txt" ];then
            touch $pwd/$url/recon/whatweb/$domain/plugins.txt
        fi
        echo "[*] Pulling plugins data on $domain $(date +'%Y-%m-%d %T') "
        whatweb --info-plugins -t 50 -v $domain >> $pwd/$url/recon/whatweb/$domain/plugins.txt; sleep 3
        echo "[*] Running whatweb on $domain $(date +'%Y-%m-%d %T')"
        whatweb -t 50 -v $domain >> $pwd/$url/recon/whatweb/$domain/output.txt; sleep 3
    done
    
    echo "[+] Scraping wayback data..."
    cat $pwd/$url/recon/final.txt | waybackurls | tee -a  $pwd/$url/recon/wayback/wayback_output1.txt
    sort -u $pwd/$url/recon/wayback/wayback_output1.txt >> $pwd/$url/recon/wayback/wayback_output.txt
    rm $pwd/$url/recon/wayback/wayback_output1.txt
    
    echo "[+] Pulling and compiling all possible params found in wayback data..."
    cat $pwd/$url/recon/wayback/wayback_output.txt | grep '?*=' | cut -d '=' -f 1 | sort -u >> $pwd/$url/recon/wayback/params/wayback_params.txt
    for line in $(cat $pwd/$url/recon/wayback/params/wayback_params.txt);do echo $line'=';done
    
    echo "[+] Pulling and compiling js/php/aspx/jsp/json files from wayback output..."
    for line in $(cat $pwd/$url/recon/wayback/wayback_output.txt);do
        ext="${line##*.}"
        if [[ "$ext" == "js" ]]; then
            echo $line | sort -u | tee -a  $pwd/$url/recon/wayback/extensions/js.txt
        fi
        if [[ "$ext" == "html" ]];then
            echo $line | sort -u | tee -a $pwd/$url/recon/wayback/extensions/jsp.txt
        fi
        if [[ "$ext" == "json" ]];then
            echo $line | sort -u | tee -a $pwd/$url/recon/wayback/extensions/json.txt
        fi
        if [[ "$ext" == "php" ]];then
            echo $line | sort -u | tee -a $pwd/$url/recon/wayback/extensions/php.txt
        fi
        if [[ "$ext" == "aspx" ]];then
            echo $line | sort -u | tee -a $pwd/$url/recon/wayback/extensions/aspx.txt
        fi
    done
    
    echo "[+] Scanning for open ports..."
    nmap -iL $pwd/$url/recon/httprobe/alive.txt -T4 -oA $pwd/$url/recon/scans/scanned.txt
    
    echo "[+] Running eyewitness against all compiled domains..."
    eyewitness=$(find / -type f -name 'EyeWitness.py')
    python3 $eyewitness --web -f $pwd/$url/recon/httprobe/alive.txt -d $pwd/$url/recon/eyewitness --resolve --no-prompt
