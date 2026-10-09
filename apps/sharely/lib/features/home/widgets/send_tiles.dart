import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';

/// Photos, Files, Link and Clip shortcuts under the laptop card.
class SendTiles extends StatelessWidget {
  const new({
    required this.onPhotos,
    required this.onFiles,
    required this.onLink,
    required this.onClip,
    super.key,
  });

  final VoidCallback? onPhotos;
  final VoidCallback? onFiles;
  final VoidCallback? onLink;
  final VoidCallback? onClip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 214,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Expanded(child: _PhotosTile(onTap: onPhotos)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                Expanded(child: _FilesTile(onTap: onFiles)),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 10,
                    children: [
                      Expanded(
                        child: _SmallTile(
                          icon: LucideIcons.link,
                          label: 'Link',
                          onTap: onLink,
                        ),
                      ),
                      Expanded(
                        child: _SmallTile(
                          icon: LucideIcons.clipboard,
                          label: 'Clip',
                          onTap: onClip,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// White rounded tile that fades when its action isn't available.
class _Tile extends StatelessWidget {
  const new({required this.onTap, required this.child, this.padding = 14});

  final VoidCallback? onTap;
  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: onTap == null ? 0.5 : 1,
      duration: SharelyMotion.fast,
      child: Material(
        color: SharelyColors.surface,
        borderRadius: const BorderRadius.all(SharelyRadii.tile),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: EdgeInsets.all(padding), child: child),
        ),
      ),
    );
  }
}

class _PhotosTile extends StatelessWidget {
  const new({required this.onTap});

  final VoidCallback? onTap;

  static const List<Color> _thumbnailShades = [
    SharelyColors.mist,
    SharelyColors.mistMid,
    SharelyColors.mistDeep,
    SharelyColors.mistLight,
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _Tile(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.25,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final shade in _thumbnailShades)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: shade,
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(
                'Photos',
                style: textTheme.titleSmall?.copyWith(fontSize: 16),
              ),
              Text(
                'Pick recent shots',
                style: textTheme.bodySmall?.copyWith(
                  color: SharelyColors.slate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilesTile extends StatelessWidget {
  const new({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _Tile(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Files',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontSize: 16),
          ),
          const Icon(LucideIcons.file, size: 22, color: SharelyColors.ink),
        ],
      ),
    );
  }
}

class _SmallTile extends StatelessWidget {
  const new({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _Tile(
      onTap: onTap,
      padding: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 20, color: SharelyColors.ink),
          Text(label, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
