UPDATE public.service_configurations 
SET "Configuration" = jsonb_set("Configuration", '{CrossOrigin}', '{
		"AllowAll": false,
		"AllowedMethod": [],
		"AllowedHeaders": [],
		"AllowedOrigins": [
			"https://*.nolucksecurity.nl",
			"http://<ip_address>:4201"
		],
		"AllowAllHeaders": true,
		"AllowAllMethods": true,
		"AllowedAllOrigins": false,
		"AllowedCredentials": true
	}', true)
WHERE "ServiceName" = 'Management API';

UPDATE public.service_configurations
SET "Configuration" = jsonb_set("Configuration", '{KeyCloakAdminApiUrl}', to_jsonb(regexp_replace( "Configuration"->'Authentication'->>'AuthorityUrl', '(/auth/)', '/auth/admin/')), true)
WHERE "ServiceName" = 'Management API';

UPDATE public.service_configurations 
SET "Configuration" = jsonb_set("Configuration", '{KeyStorageUrl}', '"http://device-key-store:8092"', true)
WHERE "ServiceName" = 'Management API';