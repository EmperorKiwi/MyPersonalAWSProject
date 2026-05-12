-- ==========================================================
-- Group 3 - Campus Resource Manager - Sample Data
-- ==========================================================
USE myprojectdb;

-- ----- 6 Bookable Services -----
INSERT INTO services (name, description, image_filename) VALUES
  ('Library Study Room',  'Private study room in the main library, seats up to 6.', 'study_room.png'),
  ('Computer Lab',        'Access to specialised software in the CS lab.',           'computer_lab.png'),
  ('Sports Hall',         'Multipurpose sports hall bookable per hour.',             'sports_hall.png'),
  ('Recording Studio',    'Media faculty recording studio with audio equipment.',    'recording_studio.png'),
  ('Meeting Room',        'Small meeting room with projector and whiteboard.',       'meeting_room.png'),
  ('AV Equipment',        'Borrow camera, tripod, and lighting kit (24h).',           'av_equipment.png');

-- ----- Sample bookings for demo purposes -----
INSERT INTO appointments (name, email, service_id, appt_date, appt_time, notes) VALUES
  ('Alice Johnson',  'alice@bcu.ac.uk',   1, CURDATE() + INTERVAL 1 DAY,  '10:00:00', 'Group project meeting'),
  ('Bob Williams',   'bob@bcu.ac.uk',     2, CURDATE() + INTERVAL 2 DAY,  '14:00:00', 'MATLAB assignment'),
  ('Carol Davies',   'carol@bcu.ac.uk',   3, CURDATE() + INTERVAL 3 DAY,  '16:30:00', 'Basketball practice'),
  ('David Miller',   'david@bcu.ac.uk',   4, CURDATE() + INTERVAL 1 DAY,  '13:00:00', 'Podcast recording'),
  ('Emma Brown',     'emma@bcu.ac.uk',    5, CURDATE() + INTERVAL 5 DAY,  '09:00:00', 'Dissertation supervision'),
  ('Frank Wilson',   'frank@bcu.ac.uk',   6, CURDATE() + INTERVAL 2 DAY,  '11:00:00', 'Film shoot');
