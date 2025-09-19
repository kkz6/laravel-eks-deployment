# Multi-Tenant Database Configuration

This Laravel deployment is configured for a multi-tenant system where Laravel needs to create and manage multiple databases dynamically.

## Database Privileges

The `laravel_user` is granted the following privileges for multi-tenant support:

### Global Privileges

- `CREATE` - Create new databases for tenants
- `DROP` - Remove tenant databases when needed
- `ALTER` - Modify database structures
- `INDEX` - Create and manage indexes
- `REFERENCES` - Create foreign key relationships

### Database-Specific Privileges

- **Main Database (`laravel_app`)**: Full privileges
- **Tenant Databases (`tenant_%`)**: Full privileges on all databases matching the pattern
- **App Databases (`app_%`)**: Full privileges on all databases matching the pattern

## Automatic Setup

When you run `./deploy.sh apply`, the system will:

1. Create the Cloud SQL instance
2. Create the main database and user
3. Automatically grant multi-tenant privileges using the generated script

## Manual Setup

If you need to grant privileges manually:

```bash
cd environment/staging/cloud-sql  # or environment/prod/cloud-sql
./grant-db-privileges.sh
```

## Laravel Configuration

Your Laravel application should be configured to:

1. Use the main database (`laravel_app`) for application data
2. Create tenant databases dynamically using patterns like:
   - `tenant_company1`
   - `tenant_company2`
   - `app_client1`
   - etc.

## Security Notes

- The user has `CREATE` and `DROP` privileges globally, which is necessary for multi-tenant systems
- All databases are accessible only via VPC (no public IP)
- SSL encryption is available if enabled in configuration

## Testing Database Privileges

You can test if the privileges are working correctly:

```bash
kubectl run mysql-test --image=mysql:8.0 --rm -i --restart=Never --namespace=laravel-app -- mysql -h <DB_HOST> -u laravel_user -p'<PASSWORD>' -e "CREATE DATABASE test_tenant_123; SHOW DATABASES; DROP DATABASE test_tenant_123;"
```

Replace `<DB_HOST>` and `<PASSWORD>` with your actual database connection details.
