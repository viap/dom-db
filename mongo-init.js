db.getSiblingDB('admin').auth(
    process.env.MONGO_INITDB_ROOT_USERNAME,
    process.env.MONGO_INITDB_ROOT_PASSWORD
);
db.getSiblingDB('admin').createUser({
    user: process.env.ME_CONFIG_BASICAUTH_USERNAME,
    pwd: process.env.ME_CONFIG_BASICAUTH_PASSWORD,
    roles: ["readWriteAnyDatabase", "dbAdminAnyDatabase"],
});