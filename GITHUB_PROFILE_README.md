<!--
  You read source before you hire. Respect.
  That's exactly how I approach every codebase I inherit.

  Backend that actually runs: https://ahmedd-dev.vercel.app/
  Problem worth solving?    ahamedhussain067@gmail.com
-->

<div align="center">

```
╔══════════════════════════════════════════════════════════════╗
║           SYED AHMED HUSSAIN  //  backend engineer           ║
║          C# · ASP.NET Core · SQL Server · EF Core           ║
╚══════════════════════════════════════════════════════════════╝
```

[![Typing SVG](https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=600&size=16&duration=2600&pause=1200&color=58A6FF&center=true&vCenter=true&width=600&lines=Backend+Engineer+%7C+.NET+%26+SQL+Server;Idempotent+APIs.+Because+double-charging+hurts.;Clean+schemas+first.+Features+second.;Runner-Up+%40+Aptech+Vision+2025)](https://ahmedd-dev.vercel.app/)

[![Portfolio](https://img.shields.io/badge/ahmedd--dev.vercel.app-0d0d0d?style=flat-square&logo=vercel&logoColor=white)](https://ahmedd-dev.vercel.app/)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-0A66C2?style=flat-square&logo=linkedin&logoColor=white)](https://linkedin.com/in/syed-ahmed-hussain)
[![Email](https://img.shields.io/badge/Email-EA4335?style=flat-square&logo=gmail&logoColor=white)](mailto:ahamedhussain067@gmail.com)
[![GitHub](https://img.shields.io/badge/GitHub-181717?style=flat-square&logo=github&logoColor=white)](https://github.com/ahmed-husssain)
![Profile Views](https://komarev.com/ghpvc/?username=ahmed-husssain&style=flat-square&color=58A6FF&label=profile+views)

</div>

---

```sql
SELECT 
    [Engineer] = 'Syed Ahmed Hussain',
    [Location] = 'Karachi, Pakistan',
    [Focus]    = 'Backend .NET | Relational Database Architecture',
    [CoreStack]= STRING_AGG(tech, ' · ') 
                 FROM (VALUES ('C#'), ('ASP.NET Core MVC'), ('Web API'), ('EF Core'), ('SQL Server')) AS T(tech),
    [Status]   = 'Shipping Production Code & Building in Public'
WHERE 
    UnhandledExceptions = 0 
    AND IdempotencyGuaranteed = 1;
```

---

## Live Projects

> These resolve. Click them.

| Project | What it is | Stack | Status |
|:--------|:-----------|:------|:------:|
| **[Online Art Gallery](https://gallrex.runasp.net)** | Full e-commerce platform for digital art — auctions, bidding engine, OAuth, shopping cart | ASP.NET Core MVC · EF Core · SQL Server · OAuth 2.0 | `RUNNING` |
| **[Shifa Management System](https://github.com/ahmed-husssain/ShifaMangementSystem)** | Comprehensive hospital & clinic management system — billing engine, responsive invoice generator, role-based workflows | Flutter · Riverpod · Supabase / PostgreSQL · Clean Architecture | `SHIPPED` |
| **[Mockrithm](https://mockrithm.me)** | AI interview prep platform — won **Runner-Up @ Aptech Vision 2025** out of all competing teams | Next.js · Firebase · REST APIs | `LIVE` |
| **[E-Books Platform](https://github.com/ahmed-husssain)** | Digital library with auth, sessions, and normalized relational schema | PHP · Relational Database · Tailwind CSS | `SHIPPED` |

---

## What I Actually Built in the Gallery

No tutorial code. Here's the stuff that required thinking:

```csharp
// Idempotency — user clicks "Place Bid" twice. Only one bid goes through.
var idempotencyKey = Request.Headers["X-Idempotency-Key"].ToString();
if (_memoryCache.TryGetValue(idempotencyKey, out object cached))
    return Json(cached);  // same response, zero duplicate processing

// Optimistic concurrency — two collectors bid at the exact same millisecond.
try { await _context.SaveChangesAsync(); }
catch (DbUpdateConcurrencyException)
{
    return Json(new { message = "Another collector bid right before you. Please refresh." });
    // no silent failure. no data corruption. just honest conflict resolution.
}

// Auction close state — price reset when admin sets a higher starting price
if (product.Price > (existing.CurrentBid ?? 0))
{
    existing.CurrentBid      = null;  // reset the bid
    existing.HighestBidderId = null;  // reset the winner
    existing.BidCount        = 0;     // reset the count
}
// because showing a "winning bid" below the starting price is not a feature.
```

> Multi-provider OAuth (Google, GitHub, Discord) · ASP.NET Core Identity RBAC · Relational schema design · Index strategy · Idempotent endpoints · Concurrency control

---

## `dotnet build`

```text
  Ahmed -> bin/Release/net8.0/Ahmed.dll

  warn APTECH2025  : Runner-Up — Aptech Vision 2025. Project: Mockrithm.
  warn OLYMPICS2025: Winner — Aptech Tech Olympics Season 1 (Master of Excel Intelligence)
  warn TECHWIZ     : Participant — Aptech TechWiz. Project: FurShield.
  info  GALLREX    : live auction engine, idempotent bids, OAuth, real users
  info  SHIFA      : clinic & hospital billing platform, role-based access control, invoice engine
  info  MOCKRITHM  : AI interview prep, Firebase backend, public deployment
  info  STUDYING   : BSSE @ Virtual University · ACCP @ Aptech (Expected Aug 2027)

Build succeeded.  0 errors.  1 award.  One stubborn love for clean schemas.
```

---

## Stack

<div align="center">

![C#](https://img.shields.io/badge/C%23-239120?style=flat-square&logo=dotnet&logoColor=white)
![ASP.NET Core](https://img.shields.io/badge/ASP.NET_Core-512BD4?style=flat-square&logo=dotnet&logoColor=white)
![EF Core](https://img.shields.io/badge/EF_Core-512BD4?style=flat-square&logo=dotnet&logoColor=white)
![SQL Server](https://img.shields.io/badge/SQL_Server-CC2927?style=flat-square&logo=microsoft&logoColor=white)
![React](https://img.shields.io/badge/React-61DAFB?style=flat-square&logo=react&logoColor=black)
![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?style=flat-square&logo=typescript&logoColor=white)
![JavaScript](https://img.shields.io/badge/JavaScript-F7DF1E?style=flat-square&logo=javascript&logoColor=black)
![Tailwind](https://img.shields.io/badge/Tailwind-06B6D4?style=flat-square&logo=tailwindcss&logoColor=white)
![PHP](https://img.shields.io/badge/PHP-777BB4?style=flat-square&logo=php&logoColor=white)
![Git](https://img.shields.io/badge/Git-F05032?style=flat-square&logo=git&logoColor=white)
![Postman](https://img.shields.io/badge/Postman-FF6C37?style=flat-square&logo=postman&logoColor=white)

</div>

```
backend/    C#  ASP.NET Core MVC  Web API  EF Core  LINQ  REST
             OAuth 2.0  Identity  RBAC  Idempotent API Design
             SQL Server  Schema Design  Indexing  Concurrency Control

frontend/   React  TypeScript  Next.js  Tailwind  GSAP  Three.js

security/   OAuth 2.0 (Google · GitHub · Discord)  ASP.NET Core Identity  JWT

tools/      Visual Studio  Git  GitHub  Postman  Firebase  Supabase
```

---

## GitHub Stats

<div align="center">
  <img src="https://github-readme-stats.vercel.app/api?username=ahmed-husssain&show_icons=true&theme=github_dark&hide_border=true&bg_color=0d0d0d&title_color=58A6FF&icon_color=58A6FF&text_color=8b949e&rank_icon=github" height="165" />
  <img src="https://github-readme-stats.vercel.app/api/top-langs/?username=ahmed-husssain&layout=compact&theme=github_dark&hide_border=true&bg_color=0d0d0d&title_color=58A6FF&text_color=8b949e&langs_count=6" height="165" />
</div>

<div align="center">
  <img src="https://streak-stats.demolab.com/?user=ahmed-husssain&theme=github-dark-blue&hide_border=true&background=0d0d0d&ring=58A6FF&fire=58A6FF&currStreakNum=ffffff&sideNums=8b949e&currStreakLabel=58A6FF&sideLabels=8b949e&dates=8b949e&timezone=Asia/Karachi" />
</div>

---

## `// stack trace of a career`

```text
at Aptech.ACCP_Student                          (Karachi, 2025 — present, Aug 2027)
   ASP.NET Core, EF Core, SQL Server, PHP, React. Building while studying.
   Runner-Up: Vision 2025 (Mockrithm). Winner: Tech Olympics S1 (Excel Intelligence).

at VirtualUniversity.BSSE_Student               (Remote, ongoing)
   BSc Software Engineering. Theory that explains the code I'm already writing.

at SelfBuilt.OnlineArtGallery                   (2025 — present)
   Full e-commerce platform. Real auctions. Real OAuth. Real concurrency problem.
   Solved it. Committed it. It's on GitHub. gallrex.runasp.net

at SelfBuilt.ShifaManagementSystem              (2025)
   Hospital and medical management system. Role-based workflow, appointment scheduling, patient records.
   github.com/ahmed-husssain/ShifaMangementSystem

at SelfBuilt.Mockrithm                          (2025)
   AI interview prep platform. Runner-Up out of all Aptech Vision 2025 entries.
   mockrithm.me — still live.

at School.Matric_CS                             (2024)
   Faiz-e-Mushtaq Education Foundation, Karachi.
   Started writing code. Didn't stop.
```

---

<div align="center">

**[ahmedd-dev.vercel.app](https://ahmedd-dev.vercel.app/)** · **[ahamedhussain067@gmail.com](mailto:ahamedhussain067@gmail.com)** · **[LinkedIn](https://linkedin.com/in/syed-ahmed-hussain)**

*If you read this far, the bid is idempotent. You can click hire twice. It's fine.*

</div>
