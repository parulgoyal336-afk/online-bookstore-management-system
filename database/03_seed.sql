BEGIN
 bookstore_pkg.register_user('Store Admin','admin@bookstore.com','Head Office','admin123');
 UPDATE users SET role='ADMIN' WHERE email='admin@bookstore.com';
 bookstore_pkg.add_book('The Alchemist','Paulo Coelho','Fiction',299,25);
 bookstore_pkg.add_book('Wings of Fire','A.P.J. Abdul Kalam','Biography',350,18);
 bookstore_pkg.add_book('Atomic Habits','James Clear','Self-Help',499,30);
 bookstore_pkg.add_book('Clean Code','Robert C. Martin','Programming',899,12);
 bookstore_pkg.add_book('Database System Concepts','Silberschatz','Programming',1199,8);
 bookstore_pkg.add_book('The Guide','R.K. Narayan','Fiction',275,20);
 bookstore_pkg.add_book('Sapiens','Yuval Noah Harari','History',599,15);
 bookstore_pkg.add_book('Rich Dad Poor Dad','Robert Kiyosaki','Finance',399,22);
 COMMIT;
END;
/
