create extension if not exists postgres_fdw; 
CREATE SERVER if not exists nolucksec FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host 'localhost', dbname 'otd', port '5432');
CREATE USER mapping if not exists FOR CURRENT_USER server nolucksec OPTIONS (user 'nolucksec', password 'nolucksec');
import foreign schema public from server nolucksec into public;

create extension if not exists "uuid-ossp";

CREATE or replace function auditFailedLogin() RETURNS trigger
AS $BODY$

	declare a varchar(255);
	declare mainId uuid;
	begin
		mainId = uuid_generate_v1();
	
		if new.error = 'invalid_user_credentials' or new.error = 'user_not_found' then
			a = 'User failed login';
		end if;
	
		if new.error = 'user_temporarily_disabled' then
			a = 'User blocked';
		end if;
	
		insert into audits ("Id" , "Username", "Role", "Action", "Status", "AdditionalInfo", "CreateTimestamp", "UpdateTimestamp")
			values (
				mainId,
				new.details_json :: json ->> 'username',
				'',
				a,
				true,
				format('{"error": "%s", "client": "%s"}', new.error, new.client_id),
				to_timestamp(new.event_time/1000),
				to_timestamp(new.event_time/1000)
			);
		
		if new.client_id = 'Enforcer' then
			insert into audit_devices ("Id", "AuditId", "CreateTimestamp", "UpdateTimestamp")
				values (
					uuid_generate_v1(),
					mainId,
					to_timestamp(new.event_time/1000),
					to_timestamp(new.event_time/1000)
				);
		end if;
	
		if new.client_id = 'MOT' then
			insert into audit_users ("Id", "AuditId", "CreateTimestamp", "UpdateTimestamp")
				values (
					uuid_generate_v1(),
					mainId,
					to_timestamp(new.event_time/1000),
					to_timestamp(new.event_time/1000)
				);
		end if;
		
		RETURN new;
   	end
$BODY$
LANGUAGE PLPGSQL;


create trigger copy_login_event_to_audit
after insert
on event_entity
for each row
execute function auditFailedLogin()
;