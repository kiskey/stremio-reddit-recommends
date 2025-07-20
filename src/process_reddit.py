import praw
import sqlite3
import configparser
import os
from sentence_transformers import SentenceTransformer
from pathlib import Path
import numpy as np
import io

# --- Helper function to adapt numpy arrays to SQLite BLOBs ---
def adapt_array(arr):
    out = io.BytesIO()
    np.save(out, arr)
    out.seek(0)
    return sqlite3.Binary(out.read())

def convert_array(text):
    out = io.BytesIO(text)
    out.seek(0)
    return np.load(out)

sqlite3.register_adapter(np.ndarray, adapt_array)
sqlite3.register_converter("array", convert_array)

def process_data():
    config = configparser.ConfigParser()
    config.read('config.ini')

    # --- Load Config ---
    SUBREDDITS = config['REDDIT']['subreddits'].split(',')
    POST_LIMIT = int(config['REDDIT']['post_limit'])
    COMMENT_SCORE_THRESH = int(config['REDDIT']['comment_score_threshold'])
    POST_SCORE_THRESH = int(config['REDDIT']['post_score_threshold'])
    MODEL_NAME = config['NLP']['sentence_transformer_model']
    IMDB_DB_FILE = Path(config['DATABASE']['imdb_database_file'])
    RECS_DB_FILE = Path(config['DATABASE']['recommendations_database_file'])

    # --- Initialize Services ---
    print("Loading SentenceTransformer model...")
    model = SentenceTransformer(MODEL_NAME)

    print("Initializing PRAW for Reddit...")
    reddit = praw.Reddit(
        client_id=os.environ['REDDIT_CLIENT_ID'],
        client_secret=os.environ['REDDIT_CLIENT_SECRET'],
        user_agent=os.environ['REDDIT_USER_AGENT'],
        username=os.environ['REDDIT_USERNAME'],
        password=os.environ['REDDIT_PASSWORD'],
    )

    # --- Connect to Databases ---
    print(f"Connecting to databases: {IMDB_DB_FILE} and {RECS_DB_FILE}")
    imdb_conn = sqlite3.connect(IMDB_DB_FILE)
    recs_conn = sqlite3.connect(RECS_DB_FILE, detect_types=sqlite3.PARSE_DECLTYPES)
    recs_cursor = recs_conn.cursor()

    # --- Create Tables in Recommendations DB if they don't exist ---
    recs_cursor.execute('''
        CREATE TABLE IF NOT EXISTS posts (
            post_id TEXT PRIMARY KEY,
            post_title TEXT,
            post_vector array
        )
    ''')
    recs_cursor.execute('''
        CREATE TABLE IF NOT EXISTS suggestions (
            suggestion_id INTEGER PRIMARY KEY AUTOINCREMENT,
            post_id TEXT,
            tt_id TEXT,
            upvotes INTEGER,
            FOREIGN KEY(post_id) REFERENCES posts(post_id)
        )
    ''')

    # --- Main Processing Loop ---
    for sub in SUBREDDITS:
        print(f"\nProcessing subreddit: r/{sub}")
        subreddit = reddit.subreddit(sub)
        try:
            for post in subreddit.hot(limit=POST_LIMIT):
                if post.score < POST_SCORE_THRESH or post.is_self is False or post.stickied:
                    continue

                print(f"\nProcessing Post: '{post.title[:50]}...' (Score: {post.score})")
                
                # Encode and store post vibe
                post_vector = model.encode(post.title)
                recs_cursor.execute("INSERT OR IGNORE INTO posts (post_id, post_title, post_vector) VALUES (?, ?, ?)",
                                  (post.id, post.title, post_vector))

                # Process comments
                post.comments.replace_more(limit=0) # Flatten comment tree
                for comment in post.comments:
                    if comment.score >= COMMENT_SCORE_THRESH:
                        # Split comment by lines to handle multiple suggestions
                        movie_titles = [line.strip() for line in comment.body.split('\n') if line.strip()]
                        for title in movie_titles:
                            # Clean title and look up in IMDb DB
                            cleaned_title = title.lower().strip().replace('*', '').replace('"', '')
                            imdb_cursor = imdb_conn.cursor()
                            imdb_cursor.execute("SELECT tconst FROM movies WHERE cleaned_title = ?", (cleaned_title,))
                            result = imdb_cursor.fetchone()
                            
                            if result:
                                tt_id = result[0]
                                print(f"  [MATCH FOUND] '{title}' -> {tt_id}")
                                recs_cursor.execute(
                                    "INSERT INTO suggestions (post_id, tt_id, upvotes) VALUES (?, ?, ?)",
                                    (post.id, tt_id, comment.score)
                                )
        except Exception as e:
            print(f"An error occurred while processing r/{sub}: {e}")
            continue

    # --- Commit and Close ---
    print("\nCommitting changes and closing database connections.")
    recs_conn.commit()
    recs_conn.close()
    imdb_conn.close()
    print("Processing complete.")


if __name__ == "__main__":
    process_data()
