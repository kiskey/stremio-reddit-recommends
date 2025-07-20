# Stremio Reddit Vibe Recommender

This project creates a Stremio addon that provides movie recommendations based on the "vibe" of user requests from Reddit's r/MovieSuggestions.

It works in two parts:
1.  **Offline Processor (GitHub Actions):** A scheduled script that scrapes Reddit, processes movie suggestions, matches them to IMDb IDs using an offline database, generates NLP vectors for the request "vibes", and saves everything into a single `recommendations.db` file.
2.  **Online Addon (Docker):** An ultra-lightweight FastAPI server that serves the pre-processed data from `recommendations.db` to Stremio. It provides both a default catalog and a powerful "vibe" search.

## Setup

1.  **Fork this repository.**

2.  **Create GitHub Secrets:** In your forked repository, go to `Settings > Secrets and variables > Actions` and create the following secrets:
    *   `REDDIT_CLIENT_ID`: Your Reddit script's client ID.
    *   `REDDIT_CLIENT_SECRET`: Your Reddit script's client secret.
    *   `REDDIT_USER_AGENT`: A unique user agent (e.g., `StremioVibeAddon/0.1 by u/YourUsername`).
    *   `REDDIT_USERNAME`: Your Reddit username.
    *   `REDDIT_PASSWORD`: Your Reddit password.

3.  **Configure the Addon:** Edit the `config.ini` file to change subreddits, NLP models, or filtering thresholds.

## How to Run

1.  **Generate the Database:** The GitHub Action will run automatically every day. To trigger the first run manually:
    *   Go to the "Actions" tab in your repository.
    *   Select "Process Reddit Movie Suggestions" from the workflows list.
    *   Click "Run workflow" > "Run workflow".
    *   After the action completes, a `recommendations.db` file will be committed to your repository.

2.  **Run the Stremio Addon:**
    *   Build the Docker image: `docker build -t stremio-vibe-addon .`
    *   Run the container: `docker run -p 8000:8000 --name stremio-vibe stremio-vibe-addon`
    *   The addon will be available at `http://localhost:8000`. Install it in Stremio by pasting the URL.
