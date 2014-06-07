function FindProxyForURL(url, host) { 
	var hosts = [%%userConfig%%]; 
	var len = hosts.length; 
	for (i = 0; i < len; i++) { 
		if (shExpMatch(host, hosts[i])) { 
			return "DIRECT"; 
		} 
	} 
	return "PROXY localhost:8181";
}