function usage()
{
	cat <<EOF
generic deploy script for docker stacks

  ## generate files for deployment:
  gpd.sh -b /srv/docker -e stage -g

Usage: "${1}" -h|--help [-b|--basedir=<basedir>] [-e|--env=<environment>] [-g|--generate] [-p|--push] [-d|--deploy] [-t|--deploy-type] [-f|--force] [-c|--clean] [-l|--docker-login] [-k|--docker-logout]

Options :
  -h, --help                     print this help text
  -b, --basedir=<BASEDIR>        provide a base directory without trailing slash (/srv/docker)
  -e, --env=<ENVIRONMENT>        select environment (e.g. local, stage, prod)
  -g, --generate                 generate config files for deployment
  -p, --push                     push config files for deployment to target
  -d, --deploy                   deploy in target
  -t, --deploy-type=<DEPLOY_TYPE select deploy type (e.g. full, backend, frontend)
  -f, --force                    force deployment
  -u, --unused                   remove unused images
  -c, --clean                    clean generated files
  -l, --docker-login             login to registry
  -k, --docker-logout            logout from registry
  -o, --geoip-disable            disable geoip database download and generation
EOF
	return 0
}

if ! options=$(getopt -o hb:e:gpdt:fuclko -l help,basedir:,environment:,generate,push,deploy,deploy-type:,force,unused,clean,docker-login,docker-logout,geoip-disable -- "$@"); then
	usage "$@"
	exit 1
fi
eval set -- "$options"

while true
do
	case "$1" in
		-h|--help)			usage "$@" && exit 1;;
		-b|--basedir)			BASEDIR="${2}"; shift 2;;
		-e|--environment)		ENVIRONMENT="${2}"; shift 2;;
		-g|--generate)			GENERATE="true"; shift 1;;
		-p|--push)			PUSH="true"; shift 1;;
		-d|--deploy)			DEPLOY="true"; shift 1;;
		-t|--deploy-type)		DEPLOY_TYPE="${2}"; shift 2;;
		-f|--force)			DEPLOY_FORCE="true"; shift 1;;
		-u|--unused)			UNUSED="true"; shift 1;;
		-c|--clean)			CLEAN="true"; shift 1;;
		-l|--docker-login)		LOGIN_DOCKER="true"; shift 1;;
		-k|--docker-logout)		LOGOUT_DOCKER="true"; shift 1;;
		-o|--geoip-disable)		GEOIP_DISABLE="true"; shift 1;;
		*)				break ;;
	esac
done
