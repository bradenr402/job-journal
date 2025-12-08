# JobJournal

A privacy-first web app to help job seekers stay organized, track every lead, application, and interview, and gain insight into their job search journey&mdash;all in one place. No messy spreadsheets. No recruiter dashboards. Just your personal job search HQ.

---

## Table of Contents

- [Overview](#overview)
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
- [Privacy & Security](#privacy--security)
- [Roadmap](#roadmap)
  - [Coming Soon](#coming-soon)
  - [Future Enhancements](#future-enhancements)
- [Contributing](#contributing)
- [License](#license)
- [Support & Contact](#support--contact)

---

## Overview

Searching for jobs is often overwhelming, chaotic, and emotionally draining&mdash;especially when juggling multiple applications, deadlines, and interview processes. Spreadsheets have long been the default tool for job hunters wanting to keep track of their job search. Every [career blog](https://www.jobscan.co/blog/job-search-spreadsheet-and-job-tracker/), [coaching platform](https://www.linkedin.com/advice/3/youre-struggling-keep-track-job-applications-hjlbc), and [Reddit advice thread](https://www.reddit.com/r/jobsearchhacks/comments/1jlmckp/the_tip_that_helped_me_secure_3_offers_in_two/) seems to preach this same gospel: “just open Excel or Google Sheets and log every lead.”

The Muse hands you a [downloadable tracker](https://www.themuse.com/advice/job-search-spreadsheet-track-application) and swears it will feel like magic once you start color-coding 30 columns. Indeed’s editorial team echoes that sentiment, offering a [step-by-step tutorial](https://www.indeed.com/career-advice/finding-a-job/job-search-spreadsheet) that turns your already grueling job search into a manual data-entry chore. SpreadsheetPoint sweetens the deal with a [template with ready-made tabs](https://spreadsheetpoint.com/templates/job-tracker-spreadsheet/) for job details, pre-interview tasks, and interview stages, yet still assumes you’ll happily maintain three separate sheets by hand.

Even productivity-oriented tools such as [Notion](https://www.notion.com/templates/category/job-application-tracking?srsltid=AfmBOopzNwEAXilhwqq0kwRUnsDPYSwLyuO24Im_6EUfgzsMFT5jvOcu) market spreadsheet-style templates as the ultimate fix, quietly ignoring the reality that human beings forget to log important details, misspell statuses, and accidentally drag a cell out of alignment at 2 a.m. after their 47th application. And Reddit is full of well-meaning users linking Google Sheets they cobbled together; [r/jobsearchhacks](https://www.reddit.com/r/jobsearchhacks/comments/1e9paqj/these_are_the_google_sheets_i_use_to_track_my_job/), [r/jobs](https://www.reddit.com/r/jobs/comments/emwcvs/protip_create_a_spreadsheet_of_jobs_youve_applied/), and [r/recruitinghell](https://www.reddit.com/r/recruitinghell/comments/1fxombf/sharing_an_application_tracker_google_sheets/) all celebrate spreadsheets because&mdash;until now&mdash;there hasn’t been anything better.

But once your search scales, the limitations of a spreadsheet become obvious. A spreadsheet never reminds you to follow-up on applications or interviews from several days ago; it can’t alert you if you forget to apply to a job lead you saved last week; and it can’t offer insights to help you easily see which sources are working. Spreadsheets silo context, scattering interview notes, thank-you drafts, meeting links, and follow-up reminders across different apps where they’re too easily forgotten. They’re error-prone and fragile: it’s easy to break formulas, delete or overwrite data, or mislabel rows&mdash;especially when your focus is already stretched thin. They lack consistency in how information is entered or categorized, aren’t mobile-friendly when you’re on the go, and offer search capabilities that are limited at best. There’s no sense of context tying leads, notes, and interviews together, and no built-in structure or encouragment to help you stay motivated. And as your search grows, spreadsheets simply don’t scale&mdash;they become harder to navigate, harder to maintain, easier to break, and less useful when you need them most.

JobJournal flips that script. Instead of forcing you to babysit cells, each opportunity is treated as a living record: timeline-aware suggestions appear automatically on your dashboard; notes are attached to the stage where they belong; helpful insights visualize which sources convert; and universal searching with tags and filters helps you easily find whatever you’re looking for, whether it’s from yesterday or from 6 months ago. JobJournal features a bird’s-eye overview of your activity, along with a customizable weekly application goal, helping you keep track of your progress and stay motivated. And smart suggestions spare you from typing the same job title, company name, source, or location again and again. By focusing on workflows rather than rows, JobJournal replaces the brittle spreadsheet paradigm with a purpose-built system that scales from a single dream role to 100 concurrent applications&mdash;without breaking your flow or compromising your privacy.

---

## Why JobJournal?

Unlike recruiter tools or job boards, JobJournal isn’t built for companies&mdash;it’s built **for you**. You stay in control of your journey, your story, and your data. Whether you're actively applying or passively looking, JobJournal is built to support your journey every step of the way&mdash;with clarity, structure, and privacy-first values at its core. Stay organized, stay motivated, and stay private with JobJournal.

---

## Tech Stack

- **Framework:** [Ruby on Rails](https://rubyonrails.org/)
- **Front-End:**
  - [Tailwind CSS](https://tailwindcss.com)
  - [Turbo](https://turbo.hotwired.dev/)
  - [Stimulus](https://stimulus.hotwired.dev/)
- **Deployment:**
  - **URL**: [job-journal.fly.dev](https://job-journal.fly.dev)
  - **Hosting Provider**: [Fly.io](https://fly.io)
  - **Status**: Available

---

## Getting Started

### Prerequisites

- Ruby 3.4.3
- Rails 8.0.2

### Setup

1. Clone the repository:

   ```shell
   git clone https://github.com/bradenr402/job-journal.git
   cd job-journal
   ```

2. Install dependencies:

   ```shell
   bundle install
   ```

3. Set up the database:

   ```shell
   bin/rails db:setup
   ```

4. Run the development server:

   ```shell
   bin/dev
   ```

The app will be available at [http://localhost:3000](http://localhost:3000).

### Running Tests

```bash
bin/rails test
```

### Passkey Configuration

JobJournal supports WebAuthn passkeys for secure, passwordless authentication.

**Browser Support:**
- Chrome/Edge 109+
- Safari 16+
- Firefox 122+

**Configuration:**

For production deployment, configure the WebAuthn origin in Rails credentials:

```bash
rails credentials:edit
```

Add:
```yaml
webauthn:
  origin: https://your-production-domain.com
```

For local development, it defaults to `http://localhost:3000` (no configuration needed).

**Usage:**

1. Sign in to your account with your password
2. Go to **Security** page
3. Click **Create Passkey** and follow your browser's prompts
4. Use biometrics (Touch ID, Face ID, Windows Hello) or a security key
5. Next time, sign in with your passkey instead of a password

**Note:** Passkeys are device-specific. Register a passkey on each device you use.

---

## Core Features

### Job Lead Management

- Track key details:
  - **Required:** Company, Job title, Application URL
  - **Optional:** Source (e.g., LinkedIn, referral), Salary, Contact, Offer amount, Location
- Timeline history:
  - Automatically records a timeline of status changes, with manual overrides when needed.
  - Statuses: `lead`, `applied`, `interview`, `offer`, `rejected`, `accepted`
- Create and reuse custom tags (e.g., `remote`, `dream job`, `priority`)
- Add unlimited notes for job details, application notes, and company research

### Alerts & Reminders

- See upcoming interviews at a glance
- Suggestions to follow up after applications and interviews
- Reminders to rate and reflect on past interviews
- Highlight stale job leads you forgot to apply to

### Interview Tracking

- Log interviews with:
  - Name of interviewer
  - Scheduled date and time
  - Location
  - Call URL
- Rate how you felt about the interview
- Add unlimited notes for prep, debrief, or feedback
- Add interviews to your calendar in a single click

### Smart Search & Filters

- Universal search for job leads, interviews, and notes
- Filter job leads by:
  - Tags
  - Status
  - Active vs. archived
- Filter interviews by date
- Filter notes by parent type: Job Lead or Interview

### Insights

- Track number of job leads, applications, and interviews per week
- Set a weekly application goal to boost motivation
- Analyze the effectiveness of job sources (referrals, job boards, etc.)
- See how far each source gets you in the hiring process
- See your most frequently used tags

---

## Privacy & Security

Your job search data should be _yours alone_. That’s why JobJournal is **privacy-first** by design: all your data stays personal, with no sharing, no tracking, and no analytics dashboards for recruiters.

- All your data is scoped to your user account.
- No third-party sharing, no analytics, no tracking, and no recruiter dashboards&mdash;your data stays private.
- Secure authentication via email & password or **passkeys**.
- Passkey support for passwordless sign-in using device biometrics or security keys.
- Delete your account and all associated data at any time at the press of a button.

---

## Roadmap

### _Coming Soon:_

- **Keyboard shortcuts for Markdown formatting in Notes**
- **Emails/Notifications**
  - Weekly activity summaries
  - Interview reminders
  - Nudges after periods of inactivity
  - Progress digests for an accountability partner
- **Milestone Tracking**
  - First interview scheduled
  - First offer received
  - Job offer accepted

### _Future Enhancements:_

- **[ActiveRecord Encryption](https://guides.rubyonrails.org/active_record_encryption.html)**  
  Encrypt user data for improved security and privacy protections
- **Context-Aware Auto-Tagging**  
  Automatically suggest tags based on job lead title, company, location, etc.
- **Note Templates**  
  Custom pre-filled notes when creating job leads or interviews
- **“Did You Apply?” Prompt**  
  Friendly reminder when visiting a job lead’s application URL
- **Autofill from Application URL**  
  Automatically extract job details from the application page

---

## Contributing

Contributions are welcome! Here’s how you can help:

1. Fork the repository.
2. Create a new branch. (`git checkout -b feature/your-feature`)
3. Commit your changes with clear commit messages.
4. Push to your fork. (`git push origin feature/your-feature`)
5. Open a pull request.

You can also report bugs or feature suggestions via [GitHub Issues](https://github.com/bradenr402/job-journal/issues).

---

## License

This project is licensed under the [MIT License](LICENSE). Feel free to use, modify, and distribute the code.

---

## Support & Contact

Have questions, feedback, or need help?  
Open an issue on GitHub, or contact me at [jobjournalapp@gmail.com](mailto:jobjournalapp@gmail.com).

---

**JobJournal**  
Your personal job search HQ.

Created with ❤️ by [Braden Roth](https://bradenroth.com)
