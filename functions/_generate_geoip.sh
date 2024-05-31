function generate_geoip()
{
	## download geoip db
	## github: https://github.com/truongnhan0311/geolite2legacy
	## updated databases: https://mailfud.org/geoip-legacy
	echo "[GPD][GENERATE] starting download of geoip databases"
	if ! wget -q -O "${STACK_FINAL_CONFIG_DIR}"/asset/nginx_geoipv4.dat.gz https://mailfud.org/geoip-legacy/GeoIPCity.dat.gz; then
		echo "[GPD][ERROR] download of geoip ipv4 database failed"
		exit 1
	else
		gunzip "${STACK_FINAL_CONFIG_DIR}"/asset/nginx_geoipv4.dat.gz
		echo "[GPD][GENERATE] download of geoip ipv4 database successful"
	fi

	if ! wget -q -O "${STACK_FINAL_CONFIG_DIR}"/asset/nginx_geoipv6.dat.gz https://mailfud.org/geoip-legacy/GeoIPv6.dat.gz; then
		echo "[GPD][ERROR] download of geoip ipv6 database failed"
		exit 1
	else
		gunzip "${STACK_FINAL_CONFIG_DIR}"/asset/nginx_geoipv6.dat.gz
		echo "[GPD][GENERATE] download of geoip ipv6 database successful"
	fi

	## generate allowed countries map
	if [[ -z "${STACK_ALLOWED_COUNTRIES}" ]]; then
		cat <<'EOF' >"${STACK_FINAL_CONFIG_DIR}"/config/nginx_allowed_countries.map
geo $local {
  default 0;
  127.0.0.1 1;
  172.22.1.0/24 1;
  fd4d:dead:beef:dead::/64 1;
}

map "$geoip_city_country_code:$geoip_country_code" $allowed_country {
  default 0;
}

map $local$allowed_country $deny {
  default 0;
}
EOF
	else
		cat <<'EOF' >"${STACK_FINAL_CONFIG_DIR}"/config/nginx_allowed_countries.map
geo $local {
  default 0;
  127.0.0.1 1;
  172.22.1.0/24 1;
  fd4d:dead:beef:dead::/64 1;
}

map "$geoip_city_country_code:$geoip_country_code" $allowed_country {
  default 0;
EOF

		for i in ${STACK_ALLOWED_COUNTRIES}; do
			cat <<EOF >>"${STACK_FINAL_CONFIG_DIR}"/config/nginx_allowed_countries.map
  "${i}:" 1;
  ":${i}" 1;
EOF
		done
		cat <<'EOF' >>"${STACK_FINAL_CONFIG_DIR}"/config/nginx_allowed_countries.map
}

map $local$allowed_country $deny {
  default 0;
  00 1;
}
EOF
	fi

	return 0
}
