# Google Cloud SQL SSL Mode Configuration

## SSL Mode Options

Google Cloud SQL supports these SSL modes:

### ✅ **Valid SSL Modes:**

| Mode                                  | Description                                   | Security Level | Use Case                   |
| ------------------------------------- | --------------------------------------------- | -------------- | -------------------------- |
| `ALLOW_UNENCRYPTED_AND_ENCRYPTED`     | Allows both SSL and non-SSL connections       | Low            | Development/Testing        |
| `ENCRYPTED_ONLY`                      | Requires SSL, but doesn't verify certificates | Medium         | Production (recommended)   |
| `TRUSTED_CLIENT_CERTIFICATE_REQUIRED` | Requires SSL with client certificates         | High           | High-security environments |

### 🚫 **Invalid Modes:**

- ~~`REQUIRE`~~ ← This was the error you encountered
- ~~`MANDATORY`~~
- ~~`FORCE_SSL`~~

## Current Configuration

Your configuration uses:

```hcl
ssl_mode = var.require_ssl ? "ENCRYPTED_ONLY" : "ALLOW_UNENCRYPTED_AND_ENCRYPTED"
```

### When `require_ssl = true` (Production):

- **Mode**: `ENCRYPTED_ONLY`
- **Behavior**: All connections must use SSL/TLS encryption
- **Certificate Verification**: Not required (easier to manage)
- **Security**: Good for most production use cases

### When `require_ssl = false` (Development):

- **Mode**: `ALLOW_UNENCRYPTED_AND_ENCRYPTED`
- **Behavior**: Allows both encrypted and unencrypted connections
- **Use Case**: Development environments where SSL setup is optional

## Laravel Application Configuration

### For `ENCRYPTED_ONLY` mode:

Update your Laravel database configuration:

```php
// config/database.php
'mysql' => [
    'driver' => 'mysql',
    'host' => env('DB_HOST'),
    'port' => env('DB_PORT', '3306'),
    'database' => env('DB_DATABASE'),
    'username' => env('DB_USERNAME'),
    'password' => env('DB_PASSWORD'),
    'options' => [
        PDO::MYSQL_ATTR_SSL_CA => env('MYSQL_ATTR_SSL_CA'),
        PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => false,
    ],
    'sslmode' => env('DB_SSLMODE', 'require'),
],
```

### Environment Variables:

```bash
# In your .env or Docker environment
DB_HOST=your-cloud-sql-ip
DB_PORT=3306
DB_DATABASE=laravel_app
DB_USERNAME=laravel_user
DB_PASSWORD=your-password
DB_SSLMODE=require
```

## SSL Certificate Management

### Google-Managed Certificates (Recommended):

- Google Cloud SQL automatically provides server certificates
- No manual certificate management required
- Certificates auto-rotate

### Client Certificates (Optional):

If you need `TRUSTED_CLIENT_CERTIFICATE_REQUIRED`:

```hcl
resource "google_sql_ssl_cert" "client_cert" {
  common_name = "laravel-client-cert"
  instance    = google_sql_database_instance.laravel_db_instance.name
}
```

## Testing SSL Connections

### From your application server:

```bash
# Test SSL connection
mysql -h YOUR_DB_IP -u laravel_user -p --ssl-mode=REQUIRED laravel_app

# Verify SSL is active
mysql> SHOW STATUS LIKE 'Ssl_cipher';
```

### Expected output:

```
+---------------+------------------+
| Variable_name | Value            |
+---------------+------------------+
| Ssl_cipher    | ECDHE-RSA-AES128-GCM-SHA256 |
+---------------+------------------+
```

## Troubleshooting

### Common Issues:

1. **Connection Refused with SSL**:

   ```bash
   # Check if SSL is properly configured
   gcloud sql instances describe laravel-db-staging --format="value(settings.ipConfiguration.sslMode)"
   ```

2. **Certificate Errors**:

   ```bash
   # Download server CA certificate
   gcloud sql instances describe laravel-db-staging --format="value(serverCaCert.cert)" > server-ca.pem
   ```

3. **Laravel Connection Issues**:
   ```php
   // Disable SSL certificate verification for Google Cloud SQL
   'options' => [
       PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => false,
   ],
   ```

## Security Best Practices

### Production Recommendations:

1. ✅ Use `ENCRYPTED_ONLY` mode
2. ✅ Restrict authorized networks to your GCP VPC
3. ✅ Use strong database passwords
4. ✅ Enable Cloud SQL audit logging
5. ✅ Regular security updates

### High-Security Environments:

1. Use `TRUSTED_CLIENT_CERTIFICATE_REQUIRED`
2. Implement client certificate rotation
3. Use private IP connections only
4. Enable VPC peering

## Cost Impact

SSL encryption has minimal cost impact:

- **Compute**: Negligible CPU overhead for SSL
- **Network**: No additional data transfer costs
- **Storage**: SSL certificates are free with Cloud SQL

## Migration Notes

If changing SSL modes:

1. **Test in staging first**
2. **Update application configuration**
3. **Plan maintenance window for production**
4. **Monitor connection errors after change**

Your current configuration with `ENCRYPTED_ONLY` provides excellent security for production use! 🔒
