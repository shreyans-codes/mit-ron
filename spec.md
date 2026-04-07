# Mit Ron Specs
1. It is a Flutter + Go App -> It allows users to create account, create groups, connect with friends. The main idea is that it eases planning meet ups between friends.
2. The App follows a dark acadamia theme. The main focus should be on managing state properly. Giving proper loading and other states.
3. The primary target devices are android, ios and mobile web.
4. The database is currently in Supabase but can be changed at any time.
5. The code needs to be modularized and should follow a abstraction strategy, all calls should be such that if the database or any other service changes, the caller should not have to change the code, a seperate layer handling the database should handle the new db and service methods.
