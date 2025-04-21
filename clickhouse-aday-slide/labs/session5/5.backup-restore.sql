-- 2. Filesystem-level backup
-- Stop ClickHouse service
$ systemctl stop clickhouse-server

-- Copy data directory
$ cp -r /var/lib/clickhouse /backup/clickhouse-data

-- 3. Using BACKUP command (21.8+)

/etc/clickhouse-server/config.d/backup_disk.xml
<clickhouse>
    <storage_configuration>
        <disks>
            <backups>
                <type>local</type>
                <path>/backups/</path>
            </backups>
        </disks>
    </storage_configuration>
    <backups>
        <allowed_disk>backups</allowed_disk>
        <allowed_path>/backups/</allowed_path>
    </backups>
</clickhouse>

TO Disk('backups', 'chat_payments_backup')
SETTINGS compression_level = 4;

BACKUP TABLE chat_payments.attachments TO Disk('backups', 'attachements.zip')

select count(*) from chat_payments.attachments
truncate table chat_payments.attachments 

RESTORE TABLE chat_payments.attachments FROM Disk('backups', 'attachements.zip')