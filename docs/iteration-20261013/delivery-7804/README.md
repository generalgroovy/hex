# Qualified 7804 portable delivery

The exact p61-7804a23eb300 portable passed package export/smoke, all 18 standalone archive checks, and isolated exported-terrain verification (132 chunks plus overview; 2,064 native checks). Two independent executions of the frozen checker each pass 3,789 checks and produce the same [combined review](../delivery-review-7804/review.json). [Full](../full-7804/README.md) and the [five-case lifecycle](../portable-lifecycle-7804-passed-a/review.json) passed separately.

The preserved fallback is exports/hex-iteration-20261013-500be. The new package is exports/hex-checkpoint-20261013-7804. Raw receipt generation fields, including checkpoint_promoted=false and installer NOT_RUN, remain unchanged. Qualification is an accompanying evidence decision, not a rewrite of those fields.

This archive preserves only exact metadata, scripts and logs; it contains no binary payload or profile contents. manifest.json records all source paths and hashes. Physical input, foreground FPS, stressed casting smoothness, audible audio quality, installer and physical networking remain separate.
