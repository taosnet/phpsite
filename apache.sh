#!/bin/sh

# Enable the use of the HTTP_DOMAIN envirnmental variable
if [ -z "$HTTP_DOMAIN" ]; then
        DOMAIN="domain"
else
        DOMAIN="$HTTP_DOMAIN"
fi

# Make sure the required directory structure exists.
if ! [ -d /var/www/$DOMAIN/public ]; then
        mkdir -p /var/www/$DOMAIN/public
fi
if ! [ -d /var/www/$DOMAIN/log ]; then
        mkdir /var/www/$DOMAIN/log
fi

# Adjust the site template configuration to match the domain.
sed -i "s/DOMAIN/$DOMAIN/g" /etc/apache2/site.conf

# Manipulate Rewrite Engine
if [ -n "$HTTP_REWRITE" ]; then
	sed -i "s/^#.*RewriteEngine.*$/        RewriteEngine $HTTP_REWRITE/" /etc/apache2/site.conf
fi

# Manipulate Overrides
if [ -n "$HTTP_OVERRIDE" ]; then
	sed -i "s/^#.*AllowOverride.*$/        AllowOverride $HTTP_OVERRIDE/" /etc/apache2/site.conf
fi

# Lets Encrypt integration
if [ -e /certs/cert.pem ] && [ -e /certs/key.pem ] && [ -e /certs/chain.pem ]; then
	if [ -e /certs/key.pem ]; then
		keyfile="key.pem"
	else
		if [-e /certs/privkey.pem ]; then
			keyfile="privkey.pem"
		fi
	fi
	echo "LoadModule ssl_module modules/mod_ssl.so
LoadModule socache_shmcb_module modules/mod_socache_shmcb.so

#
# Pseudo Random Number Generator (PRNG):
# Configure one or more sources to seed the PRNG of the SSL library.
# The seed data should be of good random quality.
# WARNING! On some platforms /dev/random blocks if not enough entropy
# is available. This means you then cannot use the /dev/random device
# because it would lead to very long connection times (as long as
# it requires to make more entropy available). But usually those
# platforms additionally provide a /dev/urandom device which doesn't
# block. So, if available, use this one instead. Read the mod_ssl User
# Manual for more details.
#
SSLRandomSeed startup file:/dev/urandom 512
SSLRandomSeed connect builtin

Listen 443
<VirtualHost *:443>
    SSLEngine on
    SSLCertificateFile /certs/cert.pem
    SSLCertificateKeyFile /certs/$keyfile
    SSLCertificateChainFile /certs/chain.pem
    SSLCipherSuite ALL:!aNULL:!ADH:!eNULL:!LOW:!EXP:RC4+RSA:+HIGH:+MEDIUM
    SSLProtocol -all +TLSv1 +TLSv1.1 +TLSv1.2

    SetEnvIf User-Agent ".*MSIE.*" \
        nokeepalive ssl-unclean-shutdown \
        downgrade-1.0 force-response-1.0

    Include /etc/apache2/site.conf
    php_flag session.use_only_cookies on
</VirtualHost>" >/etc/apache2/conf.d/ssl.conf

	if [ -n "$HTTP_REQUIRE_TLS" ] && [ "$HTTP_REQUIRE_TLS" = "yes" ]; then
		sed -i "s_^.*Include /etc/apache2/site.conf.*\$_    Redirect / https://$DOMAIN/_" /etc/apache2/httpd.conf
	fi
fi

# Start up apache2
rm -rf /run/httpd/* /tmp/httpd/*
exec httpd "$@"
