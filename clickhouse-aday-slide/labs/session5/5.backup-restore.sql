-- =============================================
-- Filesystem-level Backup (Manual)
-- =============================================

-- Stop ClickHouse service
```bash
$ systemctl stop clickhouse-server
```

-- Copy data directory
```bash
$ cp -r /var/lib/clickhouse /backup/clickhouse-data
```

-- =============================================
-- Using BACKUP Command (ClickHouse 21.8+)
-- =============================================

-- Example disk configuration: /etc/clickhouse-server/config.d/backup_disk.xml
```xml
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
```

-- Create a backup of the entire database
```sql
BACKUP DATABASE chat_payments TO Disk('backups', 'chat_payments_backup')
    SETTINGS compression_level = 4;
```

-- Create a backup of a single table
```sql
BACKUP TABLE chat_payments.attachments TO Disk('backups', 'attachments.zip');
```

-- =============================================
-- Restore Example
-- =============================================

-- Check current row count
SELECT count(*) FROM chat_payments.attachments;

-- Truncate table before restore (optional, for demonstration)
TRUNCATE TABLE chat_payments.attachments;

-- Restore table from backup
RESTORE TABLE chat_payments.attachments FROM Disk('backups', 'attachments.zip');