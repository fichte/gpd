function get_latest_docker_compose_version()
{
	if ! gpd ssh "${!STACK_DEPLOY_USER}"@"${!STACK_DEPLOY_HOST}" 'dpkg -l | grep -q  docker-compose-plugin'; then
		wget -q -O "${FINAL_CONFIG_DIR}"/docker-compose-linux-x86_64 https://github.com/docker/compose/releases/download/$(curl --silent "https://api.github.com/repos/docker/compose/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')/docker-compose-Linux-x86_64
		wget -q -O "${FINAL_CONFIG_DIR}"/docker-compose-linux-x86_64.sha256 https://github.com/docker/compose/releases/download/$(curl --silent "https://api.github.com/repos/docker/compose/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')/checksums.txt

		pushd "${FINAL_CONFIG_DIR}" &>/dev/null
		if sha256sum --quiet --ignore-missing -c docker-compose-linux-x86_64.sha256; then
			echo "successfully checked docker-compose cli-plugin"
			mv docker-compose-linux-x86_64 docker-compose
			chmod 755 docker-compose
			popd &>/dev/null
		else
			echo "docker-compose checksum mismatch"
			popd &>/dev/null
			return 1
		fi
	else
		echo "docker compose plugin found"
	fi

	if id -u -n | grep -q gitlab-runner; then
		mkdir -p ~/.docker/cli-plugins
		cp "${FINAL_CONFIG_DIR}"/docker-compose ~/.docker/cli-plugins
	fi
}
