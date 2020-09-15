function run_sql() {
    psql -U postgres -d postgres -f $1
}

declare -a database_objs
database_objs=(
    inits
    permission
    errors
    users
    sessions
    guest_session
    product
    shops
    order
)

if [[ $1 == "add-all" ]]; then
    psql -U postgres -d postgres -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp"'
    psql -U postgres -d postgres -c 'CREATE EXTENSION IF NOT EXISTS "hstore"'

    for (( i = 0; i < ${#database_objs[*]}; i++ ))
    do
        run_sql ${database_objs[i]}/add.sql
    done

elif [[ $1 == "test-all" ]]; then
    for (( i = 0; i < ${#database_objs[*]}; i++ ))
    do
        run_sql ${database_objs[i]}/test.sql
    done

elif [[ $1 == "rm-all" ]]; then
    for (( i = ${#database_objs[@]} - 1; i >= 0; i-- ))
    do
        run_sql ${database_objs[i]}/remove.sql
    done

elif [[ $1 == "prepare" ]]; then
    for (( i = 0; i < ${#database_objs[*]}; i++ ))
    do
        if [[ ${database_objs[i]} == $2 ]]; then
            break
        else
            run_sql ${database_objs[i]}/add.sql
        fi
    done

elif [[ $1 == "add" ]]; then
    run_sql $2/add.sql

elif [[ $1 == "rm" ]]; then
    run_sql $2/remove.sql

elif [[ $1 == "test" ]]; then
    run_sql $2/test.sql
    
else
    echo "Unsupported operation."
fi