# HTML Folder Changes Log

This document tracks all modifications made to files in the `/html/` directory that are not tracked by the git repository.

## Database Migration: MySQL to PostgreSQL (2025-01-04)

### Overview
Updated the comps.php page and related files to use PostgreSQL instead of the legacy MySQL server.

### Files Modified

#### 1. `/html/AIS/I/C/db.php`
- **Change**: Added new PostgreSQL connection function
- **Details**: 
  - Added `createPostgresConnection($pgDb)` function using PDO
  - Configured with credentials: host=localhost, port=5432, user=webdna_user, password=webdna_secure_password_2024
  - Kept existing MySQL connection function for backward compatibility

#### 2. `/html/AIS/I/C/config.php`
- **Change**: Added PostgreSQL database configuration
- **Details**: 
  - Added `$postgresDb="goodvaluation";` variable

#### 3. `/html/AIS/I/C/comps.php`
- **Change**: Updated database connection and queries
- **Details**: 
  - Replaced `$mysqli=createConnection($mysqlPw,$mysqlDb);` with `$pdo=createPostgresConnection($postgresDb);`
  - Converted MySQL backtick syntax to PostgreSQL double quotes
  - Updated county dropdown query: `SELECT DISTINCT "County" FROM "$table" WHERE "County" IS NOT NULL ORDER BY "County"`
  - Updated property type query: `SELECT "ID", "Property Type Improved" FROM "Land Type"`

#### 4. `/html/AIS/I/C/saveCostForm.php`
- **Change**: Converted from MySQL to PostgreSQL with prepared statements
- **Details**: 
  - Replaced mysqli connection with PDO connection
  - Updated field names from MySQL backticks to PostgreSQL double quotes
  - Converted UPDATE and INSERT statements to use prepared statements
  - Updated table name from `cost` to `"cost"`
  - Changed `$mysqli->insert_id` to `$pdo->lastInsertId()`

#### 5. `/html/AIS/I/C/handleCompIDs.php`
- **Change**: Updated database queries
- **Details**: 
  - Replaced mysqli with PDO connection
  - Updated SQL query: `SELECT "id" FROM "$table"`
  - Changed from `fetch_assoc()` to PDO `fetch()` method

#### 6. `/html/AIS/I/C/searchSection.php`
- **Change**: Converted search functionality queries
- **Details**: 
  - Replaced mysqli connection with PDO
  - Updated appraisal query: `SELECT * FROM "goodval"."celluar" WHERE "money" NOT IN ('billed','receive','logged') AND "mega15"!='yes' AND "hold"!=true ORDER BY "money","booked"`
  - Updated property type query: `SELECT DISTINCT "Property Type" FROM "$table" WHERE "Property Type" IS NOT NULL ORDER BY "Property Type"`
  - Updated county query: `SELECT DISTINCT "County" FROM "$table" WHERE "County" IS NOT NULL ORDER BY "County"`

### Technical Notes
- All queries now use PostgreSQL-compatible syntax with double quotes for identifiers
- Prepared statements implemented for security
- PDO used instead of mysqli for PostgreSQL compatibility
- Database credentials match the Docker PostgreSQL container configuration

### Status
- Code changes complete
- Ready for data migration to PostgreSQL
- Page accessible at: `10.10.0.118:8080/theprogram/comps.php`

### Related Infrastructure
- PostgreSQL container: `webdna-postgres` (port 5432)
- Database: `goodvaluation`
- User: `webdna_user`
- Container status: Running and healthy

---

## PHP Installation and Configuration (2025-01-04)

### Overview
Installed PHP support in the webdna-server container to enable PHP page rendering.

### Issue Identified
- PHP webpages were not rendering (showing raw PHP code instead of executing)
- webdna-server container only had Apache and WebDNA module installed
- No PHP runtime or Apache PHP module was present

### Solution Implemented
- Installed PHP 8.1 and required extensions in the running container
- Enabled Apache PHP module for PHP processing

### Commands Executed
```bash
docker exec webdna-server apt update
docker exec webdna-server apt install -y php libapache2-mod-php php-pgsql php-mysql
docker exec webdna-server service apache2 restart
```

### Packages Installed
- php (2:8.1+92ubuntu1)
- libapache2-mod-php8.1 (8.1.2-1ubuntu2.21)
- php8.1-pgsql (PostgreSQL support)
- php8.1-mysql (MySQL support)
- Associated dependencies and PHP extensions

### Status
- PHP 8.1.2 now operational
- Apache PHP module loaded and functioning
- PHP pages now render correctly
- Database extensions available for both PostgreSQL and MySQL connections

### Test Results
- Basic PHP functionality: ✅ Working
- Page rendering: ✅ Working
- Available for both database backends: ✅ Ready

### Notes
- This was initially a runtime fix applied to the existing container
- **UPDATE**: Dockerfile has now been updated to include PHP installation for future builds
- Database connections from container need proper network configuration

### Dockerfile Updates Applied
The following changes were made to `/build/docker/Dockerfile` to ensure PHP is included in future builds:

```dockerfile
# Added PHP packages to installation
RUN apt-get update && apt-get install -y \
    apache2 \
    curl \
    ca-certificates \
    # PHP and extensions
    php \
    libapache2-mod-php \
    php-pgsql \
    php-mysql \
    # Security and monitoring tools
    htop \
    nano \
    # Cleanup
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Updated Apache modules to include PHP
RUN a2enmod rewrite headers webdna speling alias dir php8.1
```

### Future Deployment
- New container builds will automatically include PHP 8.1 support
- No manual PHP installation required for fresh deployments
- PostgreSQL and MySQL extensions included by default

---

## Bootstrap and Static Assets Fix (2025-01-04)

### Overview
Fixed missing Bootstrap, jQuery, and other static assets that were causing 404 errors in Apache logs.

### Issue Identified
- Multiple missing CSS and JavaScript files causing Apache 404 errors
- Files were being requested from `/theprogram/`, `/css/`, `/js/`, and `/library/` directories that didn't exist
- Missing files included:
  - `bootstrap.min.css`, `bootstrap.min.js`
  - `jquery.min.js`, `jquery-migrate-1.1.1.min.js`
  - Various jQuery plugins (jeditable, tooltip, validate, etc.)
  - File browser components
  - Custom CSS files (liveSearch.css, flowStyles.css, modes.css)

### Solution Implemented
- **Created missing directory structure**:
  - `/html/theprogram/` with subdirectories: css, js, library, fileBrowser
  - `/html/css/`, `/html/js/`, `/html/library/` for root-level access
  - `/html/images/` for static images

- **Copied existing files from various locations**:
  - Bootstrap files from `/AIS/GROUPS/GOODVALUATION/css/` and `/js/`
  - jQuery files from `/trunk/Library/`
  - Additional plugins from `/AIS/GROUPS/GOODVALUATION/library/migration/LIBRARY/`
  - File browser components from `/AIS/I/C/FileBrowser/`

- **Created missing files**:
  - `liveSearch.css` - Live search styling
  - `flowStyles.css` - Flow container styling  
  - `modes.css` - Mode toggle styling
  - `145ba98491.js` - Placeholder for dynamically named script

### Files Created/Organized

#### Directory Structure
```
/html/
├── theprogram/
│   ├── css/ (Bootstrap, custom CSS)
│   ├── js/ (Bootstrap, jQuery migrate)
│   ├── library/ (jQuery plugins, utilities)
│   ├── fileBrowser/ (File browser components)
│   └── *.js (Root level scripts)
├── css/ (Root level CSS access)
├── js/ (Root level JS access)
├── library/ (Root level library access)
└── images/ (Static images)
```

#### Key Files Resolved
- **Bootstrap**: `bootstrap.min.css`, `bootstrap.min.js`
- **jQuery**: `jquery.min.js`, `jquery-ui.js`, `jquery-migrate-1.1.1.min.js`
- **Plugins**: `jquery.jeditable.js`, `jquery.validate.pack.js`, `jquery.tooltip.js`
- **Utilities**: `fileFunctions.js`, `editstuff.js`, `modes.js`
- **File Browser**: `mimeTypes.js`, `fileBrowser.js`, `jqueryFileTree/*`

### Test Results
- All static assets now return HTTP 200 status
- Bootstrap CSS: ✅ `/theprogram/css/bootstrap.min.css`
- Bootstrap JS: ✅ `/theprogram/js/bootstrap.min.js`  
- jQuery: ✅ `/theprogram/library/jquery.min.js`
- Root access: ✅ `/css/`, `/js/`, `/library/` directories working

### Status
- ✅ Apache 404 errors resolved for static assets
- ✅ Bootstrap and jQuery properly accessible
- ✅ File browser components available
- ✅ Both `/theprogram/` and root-level access paths working
- ✅ WebDNA templates (.tpl) and PHP pages can access resources

### Notes
- Files were sourced from existing locations within the project
- Both `/theprogram/` and root-level paths are supported for compatibility
- Custom CSS files created with basic styling to prevent errors
- Directory structure follows common web development practices

---

## Future Changes

*Add new changes below this line following the same format*
