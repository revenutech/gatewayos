---
title: "Security Awareness Program — API Gateway ISMS"
iso_ref: "ISO/IEC 27001:2022 Clause 7.3, ISO/IEC 27002:2022 A.6.3"
version: "1.0"
status: Active
last_review: 2026-03-25
next_review: 2026-09-25
owner: Compliance Officer
classification: Internal
---

# Security Awareness Program — API Gateway ISMS

## 1. Purpose

Ensures all persons doing work under the organization's control related to the API Gateway are aware of (ISO 27001 Cl. 7.3):

a) The information security policy (B1-GW)
b) Their contribution to the effectiveness of the ISMS
c) The implications of not conforming with ISMS requirements

## 2. Awareness Requirements

### 2.1 What Personnel Must Know

| Topic | Content | ISO Ref |
|-------|---------|---------|
| **Security Policy** | B1-GW principles (defense-in-depth, zero trust, least privilege, fail secure, audit everything) | Cl. 7.3a |
| **Their Role** | RACI responsibilities specific to their function | Cl. 7.3b |
| **Incident Reporting** | How to report security events (Slack #security, IRP procedures) | A.6.8 |
| **Access Control** | JWT/RBAC model, API key handling, token revocation procedures | A.8.5, A.5.15 |
| **Change Management** | PR review process, CODEOWNERS rules, CI security gates | A.8.32 |
| **Data Handling** | No PII in logs, classification labels, DLP awareness | A.5.34, A.8.11 |
| **Regulatory Obligations** | BACEN incident notification (24h), LGPD breach notification (72h) | A.5.31 |
| **Consequences** | Policy violation handling (B1-GW §7), corrective action process | Cl. 7.3c |

### 2.2 Who Must Be Aware

| Group | Scope | Awareness Level |
|-------|-------|----------------|
| Gateway developers | Config, Lua plugins, endpoints | Full technical + policy |
| DevSecOps team | Operations, monitoring, incidents | Full technical + operational |
| Security Architect | Design, review, threat modeling | Full all areas |
| Compliance Officer | Audit, evidence, regulatory | Full governance + regulatory |
| ISMS Owner | Oversight, decisions | Policy + governance |
| External contractors (if any) | Scoped to their access | Relevant subset + NDA |

## 3. Awareness Activities

### 3.1 On-boarding (New Team Members)

| Activity | Duration | Delivered By | Evidence |
|----------|----------|-------------|----------|
| Read B1-GW security policy | 30 min | Self-study | Signed acknowledgment |
| Read CLAUDE.md ISO compliance section | 15 min | Self-study | Signed acknowledgment |
| Gateway architecture security walkthrough | 1 hour | Security Architect | Attendance record |
| RACI roles briefing | 30 min | ISMS Owner | Attendance record |
| Incident reporting procedure | 30 min | DevSecOps Lead | Attendance record |
| Sign Policy Acknowledgment Form | 5 min | Self | Signed form (see §5) |

### 3.2 Quarterly Refresher

| Quarter | Topic | Format | Duration |
|---------|-------|--------|----------|
| Q1 | Threat landscape update + STRIDE refresh | Presentation + discussion | 1 hour |
| Q2 | Incident response drill (tabletop exercise) | Scenario simulation | 2 hours |
| Q3 | BACEN/LGPD regulatory updates | Briefing | 1 hour |
| Q4 | ISMS performance review + lessons learned | Management review summary | 1 hour |

### 3.3 Event-Triggered Awareness

| Trigger | Activity | Timeline |
|---------|----------|----------|
| Security incident (P1/P2) | Post-mortem briefing to all team | Within 10 business days |
| Policy update | Notification + new acknowledgment | Within 5 business days |
| New regulatory requirement | Briefing by Compliance Officer | Within 15 business days |
| New team member joins | Full on-boarding (§3.1) | First week |
| Major architecture change | Security impact briefing | Before deployment |

## 4. Awareness Delivery Methods

| Method | Use Case | Evidence |
|--------|----------|----------|
| **In-person / video call** | Walkthroughs, drills, briefings | Attendance record |
| **CLAUDE.md** | Developer quick-reference during coding | Git access log |
| **PR review comments** | Just-in-time security guidance | PR review history |
| **Slack #security** | Announcements, advisories, incident updates | Message history |
| **Email** | Formal policy communications, acknowledgment requests | Email receipt |
| **Git commits** | ISO annotations in code reinforce controls awareness | Commit history |

## 5. Policy Acknowledgment Form

### Template

```
SECURITY POLICY ACKNOWLEDGMENT — API Gateway ISMS

I, [FULL NAME], in my role as [ROLE], acknowledge that:

1. I have read and understand the Information Security Policy (B1-GW)
2. I understand my responsibilities as defined in the RACI matrix
3. I understand how to report security events (Slack #security, IRP)
4. I understand the consequences of not conforming with ISMS requirements
5. I commit to applying information security in my daily work

Signed: ________________________
Date:   ________________________
Role:   ________________________

Witnessed by: __________________  (ISMS Owner or delegate)
```

### Acknowledgment Schedule

| When | Required |
|------|----------|
| On-boarding | Within first week |
| Annual renewal | January each year |
| After policy update | Within 5 business days of notification |

### Acknowledgment Register

| Date | Person | Role | Policy Version | Signature | Witness |
|------|--------|------|---------------|-----------|---------|
| | | | | | |

## 6. Effectiveness Measurement

| Metric | Target | Method | ISO 27004 Ref |
|--------|--------|--------|---------------|
| Acknowledgment completion rate | 100% | Register count vs. team size | M18 (doc currency) |
| Quarterly session attendance | > 90% | Attendance records | — |
| Incident response drill score | Pass (correct actions taken) | Drill evaluation | M14 (MTTD) |
| Security-related PR review quality | No security issues missed in review | Quarterly sample review | M11 (CI pass rate) |
| Policy violation rate | 0 per quarter | Corrective actions register | M19 (CA closure) |

## 7. Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-25 | Compliance Officer | Initial awareness program |
