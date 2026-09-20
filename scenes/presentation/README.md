# Visual asset gallery

Run the standalone presentation scene to review the first generated environment,
Nico Lai animation atlas and compact icon families without replacing the main
bootstrap scene:

```bash
"$FLUX2_GODOT" --path . res://scenes/presentation/visual_asset_gallery.tscn
```

The gallery is presentation-only. It uses `VisualAssetRegistry` and
`SkeletonAnimationLibrary`; it does not own movement, collision, combat,
chemistry or network authority.
