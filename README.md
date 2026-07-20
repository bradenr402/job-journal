# JobJournal

A privacy-first job search tracker. Organize every lead, application, and interview in one place&NoBreak;&mdash;with smart insights to help you see what’s working. No messy spreadsheets. No data selling. No recruiter dashboards.

---

## Table of Contents

- [Overview](#overview)
  - [Spreadsheets weren’t built for this](#spreadsheets-werent-built-for-this)
  - [JobJournal flips that script](#jobjournal-flips-that-script)
- [Why JobJournal?](#why-jobjournal)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Setup](#setup)
  - [Running Tests](#running-tests)
- [Core Features](#core-features)
  - [Job Lead Management](#job-lead-management)
  - [Alerts & Reminders](#alerts--reminders)
  - [Interview Tracking](#interview-tracking)
  - [Smart Search & Filters](#smart-search--filters)
  - [Insights](#insights)
  - [Autofill From URL](#autofill-from-url)
- [Privacy & Security](#privacy--security)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)
- [Support & Contact](#support--contact)

---

## Overview

Searching for jobs is often overwhelming, chaotic, and emotionally draining. So everyone reaches for a spreadsheet because, until now, there hasn’t been anything better.

### Spreadsheets weren’t built for this.

When you’re juggling multiple applications, deadlines, and interviews, everyone seems to preach the same gospel: “just open Excel or Google Sheets and log every lead.” It works&mdash;until it doesn’t.

- Spreadsheets don’t remind you to follow up, flag stale leads, or tell you which sources are working.
- Notes, meeting links, and interview prep end up scattered across apps where they’re too easily forgotten.
- The more applications you add, the harder they are to maintain&mdash;and the less useful they become.

### JobJournal flips that script.

Instead of babysitting cells, every opportunity becomes a **living record**. Follow-up suggestions and stale job lead alerts surface on your dashboard automatically. Notes stay attached to the stage they belong to. Insights show which sources actually convert. And universal search finds anything instantly.

**Focus on your workflow, not managing rows.** JobJournal scales from a single dream role to 100 concurrent applications&mdash;without breaking your flow or compromising your privacy.

---

## Why JobJournal?

Recruiter tools serve companies. Job boards serve advertisers. JobJournal serves **you**—keeping you in control of your job search and your data.

---

## Tech Stack

- **Framework:** [Ruby on Rails](https://rubyonrails.org/)
- **Database:** [SQLite](https://www.sqlite.org/)
- **Front-End:**
  - [Tailwind CSS](https://tailwindcss.com) v4
  - [Turbo](https://turbo.hotwired.dev/)
  - [Stimulus](https://stimulus.hotwired.dev/)
  - [Importmap](https://github.com/rails/importmap-rails)
- **Deployment:**
  - **URL**: [job-journal.fly.dev](https://job-journal.fly.dev)
  - **Hosting Provider**: [Fly.io](https://fly.io)
  - **Status**: Available

---

## Getting Started

JobJournal is available for free at [job-journal.fly.dev](https://job-journal.fly.dev). If you’d like to run it locally, follow the instructions below.

### Prerequisites

- Ruby 3.4.3
- Rails 8.0.2

### Setup

1. Clone the repository:

   ```shell
   git clone https://github.com/bradenr402/job-journal.git
   cd job-journal
   ```

2. Run the setup script, which installs dependencies and prepares the database:

   ```shell
   bin/setup
   ```

   Or set up manually:

   ```shell
   bundle install
   bin/rails db:prepare
   ```

3. (Optional) Seed the database with demo data:

   ```shell
   bin/rails db:seed
   ```

   This creates a demo account (email: `demo@jobjournal.app`, password: `password`) with sample job leads, interviews, notes, and tags.

4. Run the development server:

   ```shell
   bin/dev
   ```

   This starts the Rails server and the Tailwind CSS watcher.

The app will be available at [http://localhost:3000](http://localhost:3000).

### Running Tests

Run the full test suite:

```shell
bin/rails test
```

Run a single test file:

```shell
bin/rails test test/models/user_test.rb
```

---

## Core Features

### Job Lead Management

- Track key details: company, title, salary, contact, location, etc.
- Automatically records a timeline of status changes, with manual overrides when needed.
- Categorize job leads with unlimited tags for easy filtering and searching
- Add unlimited notes for additional job details, company research, or anything else you want to remember

### Insights That Guide You

- Track number of job leads, applications, and interviews per week
- Set a weekly application goal to boost motivation
- See which sources actually convert to interviews and offers

### Interview Tracking

- Log interviewer, date, location, and call link
- Add to your calendar in one click
- Rate how you felt about the interview
- Add unlimited notes for prep, debrief, or feedback

### Dashboard Overview

- Weekly stats and progress toward your application goal
- Upcoming interviews at a glance
- Smart follow-up suggestions after applications and interviews
- Gentle reminders to rate and reflect on past interviews
- Stale job leads you forgot to apply to
- Your most recent notes to help you pick up where you left off

### Smart Search & Filters

- Search across job leads, interviews, and notes
- Narrow resutls with filters:
  - Job Leads by tag, status, and archive state
  - Interviews by date
  - Notes by parent type and archive state

### Autofill From URL

- Enter a job posting URL to auto-extract job details
- Fills in company, title, location, and more&mdash;no manual input required
- Review and edit any field before saving
- Currently supports **Indeed** and **LinkedIn**, with more sources on the way
  - Want autofill for another source? Feel free to [open an issue](https://github.com/bradenr402/job-journal/issues/new) or contribute a PR!

---

## Privacy & Security

Your job search data should be _yours alone_. JobJournal is **privacy-first** by design—no third-party sharing, no data selling, no recruiter analytics.

Your data stays scoped to your account, and you can delete it all at any time.

---

## Roadmap

- **Note Templates**  
  Custom pre-filled notes when creating job leads or interviews
- **“Did You Apply?” Prompt**  
  Friendly reminder when visiting a job lead’s application URL
- **Keyboard Shortcuts for Markdown Formatting in Notes**
- **Passkey Support**
- **Emails & Notifications**
  - Weekly activity summaries
  - Interview reminders
  - Nudges after periods of inactivity
  - Progress digests for an accountability partner

---

## Contributing

Contributions are welcome! Here’s how you can help:

1. Fork the repository.
2. Create a new branch: `git checkout -b feature/your-feature`
3. Make your changes, adding tests where appropriate.
4. Ensure the test suite passes (`bin/rails test`) and the code is lint-clean (`bin/rubocop`).
5. Commit your changes with clear commit messages.
6. Push to your fork: `git push origin feature/your-feature`
7. Open a pull request.

You can also report bugs or feature suggestions via [GitHub Issues](https://github.com/bradenr402/job-journal/issues).

---

## License

This project is licensed under the [MIT License](LICENSE). Feel free to use, modify, and distribute the code.

---

## Support & Contact

Have questions, feedback, or need help?  
[Open an issue](https://github.com/bradenr402/job-journal/issues/new), or contact me at [jobjournalapp@gmail.com](mailto:jobjournalapp@gmail.com).

---

**JobJournal**  
A privacy-first job search tracker. Organize every lead, application, and interview in one place.

Created with ❤️ by [Braden Roth](https://bradenroth.com)
