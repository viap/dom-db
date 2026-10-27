// Runs only when the data volume is initialised for the first time; it has no
// effect on an existing database.
//
// The root user comes from MONGO_INITDB_ROOT_*. No other users are created
// here: the mongo-express basic-auth credentials used to become a database
// user with readWriteAnyDatabase + dbAdminAnyDatabase, which nothing needs.
// Create least-privilege service users by hand (see ai-context/STATE.md).
