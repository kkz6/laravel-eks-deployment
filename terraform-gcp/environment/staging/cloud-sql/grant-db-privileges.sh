#!/bin/bash
# Script to grant database privileges to Laravel user for multi-tenant system

echo "Granting multi-tenant privileges to laravel_user..."

kubectl run mysql-grant-privileges \
  --image=mysql:8.0 \
  --rm -i --restart=Never \
  --namespace=laravel-app \
  -- mysql \
  -h 10.83.0.3 \
  -u root \
  -p'YR2OnxKr0N)k8v@j' \
  -e "
    -- Grant privileges for multi-tenant system
    GRANT CREATE ON *.* TO 'laravel_user'@'%';
    GRANT DROP ON *.* TO 'laravel_user'@'%';
    GRANT ALTER ON *.* TO 'laravel_user'@'%';
    GRANT INDEX ON *.* TO 'laravel_user'@'%';
    GRANT REFERENCES ON *.* TO 'laravel_user'@'%';
    
    -- Grant full privileges on main database
    GRANT ALL PRIVILEGES ON laravel_app.* TO 'laravel_user'@'%';
    
    -- Grant privileges on all tenant databases (pattern-based)
    GRANT ALL PRIVILEGES ON \`tenant_%\`.* TO 'laravel_user'@'%';
    GRANT ALL PRIVILEGES ON \`app_%\`.* TO 'laravel_user'@'%';
    
    -- Flush privileges and show grants
    FLUSH PRIVILEGES;
    SHOW GRANTS FOR 'laravel_user'@'%';
  "

echo "Multi-tenant privileges granted successfully!"
echo "Laravel user can now:"
echo "  - Create/Drop databases"
echo "  - Manage all tenant databases"
echo "  - Full access to main database: laravel_app"
