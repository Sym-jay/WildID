# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

- **Field officers and researchers** (ZSI staff, forest and fisheries officers, marine researchers). They check a catch, a landing-site specimen or a seized animal, usually outdoors on an Android phone in strong light, often with wet or gloved hands. Their job: decide quickly whether the animal is a protected species and record the sighting with location.
- **Fishers and coastal community members.** Non-experts reporting a catch to learn whether it is protected. English literacy may be limited and the network patchy, so they need plain language and large, obvious actions.

## Product Purpose

WildID (ZSI Wildlife Identifier) identifies endangered and CITES / Wildlife Protection Act Schedule I–II marine species from a photo. It gives the likely species with a confidence level, its protection status and basic species facts, and logs the observation (photo, time, GPS) for expert verification. Success: a user gets a trustworthy answer on whether the animal is protected within seconds, and ZSI receives verified, located sighting records.

## Positioning

Built on Zoological Survey of India data and focused on the protected marine species of Indian waters (sharks, rays, guitarfish, sawfish, seahorses, groupers, snakeheads). Each answer comes with protection status and an expert verification queue, not just a species name.

## Operating Context

- Capture with the camera or pick from the gallery, then cloud AI identification (EfficientNet-B0, optional ensemble) with an offline fallback. Shows the top results and confidence.
- Metadata form (location, notes), upload history, CSV export.
- Expert verification queue and admin dashboard for reviewers.
- SMS alerts for endangered identifications and verification results.
- Accounts are local to the device (email/password, or OTP via the backend). Guest mode exists.

## Capabilities and Constraints

- Flutter app (`Frontend/ZSI_Frontend`), Android first; iOS and web build but follow the Android design.
- Species content: 66 species in `assets/species_data.json` with images in `assets/species_images/`.
- Model accuracy figures in older docs (98.47%, 75% ensemble) disagree with each other. Do not show accuracy claims in the UI until they are confirmed.
- Network can be slow or absent in the field.

## Brand Commitments

- Keep the ZSI / Zoological Survey of India name and the existing logo (`assets/images/logo.jpg`).
- Keep green as the brand colour family. Everything else about the current look is replaceable.

## Evidence on Hand

- Species data and photos listed above. There are no testimonials, user counts or partner claims, and none should be invented.

## Product Principles

1. **Protected or not, first.** The protection status is the headline of every result, ahead of taxonomy.
2. **Honest confidence.** Show uncertainty plainly and suggest a retake instead of overstating a match.
3. **Field-proof.** Large targets, high contrast in sunlight, and graceful degradation offline.
4. **Plain language.** Common names and short sentences first; scientific detail on request.

## Accessibility & Inclusion

Outdoor use in sunlight and users with limited English literacy: WCAG AA contrast at minimum, 48dp touch targets, icons paired with text, and support for system font scaling.
