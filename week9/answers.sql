-- Create your tables, views, functions and procedures here!
CREATE SCHEMA social;
USE social;



CREATE TABLE users(
user_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
first_name VARCHAR(50) NOT NULL,
last_name VARCHAR(50) NOT NULL,
email VARCHAR(100) NOT NULL,
created_on TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE sessions(
session_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
user_id INT UNSIGNED,
created_on TIMESTAMP NOT NULL DEFAULT NOW(),
updated_on TIMESTAMP NOT NULL DEFAULT NOW() ON UPDATE NOW(),
FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE friends(
user_friend_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
user_id INT UNSIGNED,
friend_id INT UNSIGNED,
FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
FOREIGN KEY (friend_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- to anyone looking through my code if get an error 1452 look at this table. Might save you the headache. 
CREATE TABLE posts(
post_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
user_id INT UNSIGNED,
created_on TIMESTAMP NOT NULL DEFAULT NOW(),
updated_on TIMESTAMP NOT NULL DEFAULT NOW() ON UPDATE NOW(),
content VARCHAR (250) NOT NULL,
FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
)AUTO_INCREMENT = 6;

CREATE TABLE notifications(
notification_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
user_id INT UNSIGNED,
post_id INT UNSIGNED NULL,
FOREIGN KEY (user_id) REFERENCES users(user_id),
FOREIGN KEY (post_id) REFERENCES posts(post_id) ON DELETE SET NULL
);

-- notification view 
CREATE VIEW notification_posts AS
SELECT
    notif.user_id AS notification_user_id,
    users.first_name,
    users.last_name,
    posts.post_id,
    posts.content
FROM 
    notifications notif
LEFT JOIN posts ON notif.post_id = posts.post_id
LEFT JOIN users post_creator ON posts.user_id = post_creator.user_id;


DELIMITER $$

CREATE PROCEDURE AddNewUser(
    IN new_user_id INT,
    IN new_first_name VARCHAR(50),
    IN new_last_name VARCHAR(50)
)
BEGIN
    -- Insert notifications for all existing users except the new user
    INSERT INTO notifications (user_id, post_id)
    SELECT user_id, NULL
    FROM users
    WHERE user_id != new_user_id;

    -- Insert a post for the new user
    INSERT INTO posts (user_id, content)
    VALUES (
        new_user_id,
        CONCAT(new_first_name, ' ', new_last_name, ' just joined!')
    );
END$$

DELIMITER ;


DELIMITER $$
CREATE PROCEDURE DeleteOldSessions()
BEGIN
    DELETE FROM sessions
    WHERE updated_on < NOW() - INTERVAL 2 HOUR;
END$$
DELIMITER ;



DELIMITER $$
CREATE PROCEDURE add_post(IN user_id INT, IN content VARCHAR(250))
BEGIN
    DECLARE new_post_id INT;

    -- Insert the new post into the posts table
    INSERT INTO posts (user_id, content, created_on, updated_on)
    VALUES (user_id, content, NOW(), NOW());

    -- Get the post_id of the newly inserted post
    SET new_post_id = LAST_INSERT_ID();

    -- Create notifications for all friends of the user
    INSERT INTO notifications (user_id, post_id)
    SELECT friend_id, new_post_id
    FROM friends
    WHERE user_id = add_post.user_id;

END$$

DELIMITER ;

