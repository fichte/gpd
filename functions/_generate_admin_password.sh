function generate_admin_password()
{
	echo "[GPD][GENERATE] generating stack admin management password"
	STACK_ADMIN_MANAGEMENT_PASSWORD=$(echo "${ENVIRONMENT^^}"_STACK_ADMIN_MANAGEMENT_PASSWORD)

	if htpasswd -b -c "${STACK_FINAL_CONFIG_DIR}"/config/nginx_nginxpasswd admin ${!STACK_ADMIN_MANAGEMENT_PASSWORD} 2>/dev/null; then
		PORTAINER_PASSWORD=$(htpasswd -nbB admin ${!STACK_ADMIN_MANAGEMENT_PASSWORD} | cut -d ":" -f 2 | sed -e 's;\$;\$\$;g')
		STACK_ADMIN_PASSWORD=$(htpasswd -bnBC 8 "" ${!STACK_ADMIN_MANAGEMENT_PASSWORD} | tr -d ':\n')
		STACK_ADMIN_10_PASSWORD=$(htpasswd -bnBC 10 "" ${!STACK_ADMIN_MANAGEMENT_PASSWORD} | tr -d ':\n')

		sed -i 's;__PORTAINER_PASSWORD__;'"${PORTAINER_PASSWORD}"';g' "${STACK_FINAL_CONFIG_DIR}"/compose/*
		sed -i 's;__STACK_ADMIN_PASSWORD__;'"${STACK_ADMIN_PASSWORD}"';g' "${STACK_FINAL_CONFIG_DIR}"/config/*
		sed -i 's;__STACK_ADMIN_10_PASSWORD__;'"${STACK_ADMIN_10_PASSWORD}"';g' "${STACK_FINAL_CONFIG_DIR}"/config/*
		echo "[GPD][GENERATE] generating stack admin management password successful"
		return 0
	else
		echo "[GPD][GENERATE]][ERROR] generating stack admin management password failed"
		return 1
	fi
}
