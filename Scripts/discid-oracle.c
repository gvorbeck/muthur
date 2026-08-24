/* Ground truth for the disc ID tests, from the reference implementation.
 *
 * MUTHURKit computes the MusicBrainz disc ID itself, in Swift, so that the
 * arithmetic is testable on a machine with nothing in the drive — see
 * MUTHURKit/Sources/MUTHURKit/Disc/TableOfContents.swift and docs/parity.md
 * §4.3. That leaves the obvious question of what the answers are checked
 * against, and the answer must not be "the same arithmetic written twice".
 *
 * discid_put() takes a table of contents and needs no drive at all, which makes
 * libdiscid usable as an oracle offline: hand it the TOC, print what it says,
 * paste that into the suite. Every expected disc ID in DiscIDTests.swift came
 * out of this program.
 *
 * The TOCs below are documented examples rather than TOCs invented here, so the
 * test is against a published pressing and not against a shape that happens to
 * suit the code:
 *
 *   - "libdiscid" is the example in discid.h's own documentation of
 *     discid_get_toc_string() — "1 7 164900 150 22460 50197 80614 100828
 *     133318 144712".
 *   - "fifteen" is a fifteen-track disc, for a TOC long enough that the 99-slot
 *     zero padding is doing visible work.
 *   - "single" is one track, the shortest TOC there is.
 *
 *   brew install libdiscid
 *   cc Scripts/discid-oracle.c -I"$(brew --prefix libdiscid)/include" \
 *      -L"$(brew --prefix libdiscid)/lib" -ldiscid -o /tmp/discid-oracle
 *   /tmp/discid-oracle
 *
 * With a disc in the drive there is a second mode, `read [device]`, which asks
 * the drive itself rather than a table typed out here. It is the check in
 * docs/parity.md §19 that closes the loop: the ID libdiscid gets off the disc in
 * front of you against the one MUTHURKit computes from the same disc's cdrecord
 * listing. **It opens the device exclusively**, so run `drutil status` before it
 * and not after — see §1.3 and burncd:278.
 *
 * Not built by the package and not linked into it. Whether libdiscid also ends
 * up reading the TOC in the shipping app is §18.18, still open; computing an ID
 * out of a TOC and reading a TOC off a drive are different jobs, and only the
 * first one is settled. Either way this stays a loose file rather than becoming
 * a build dependency of a package that must compile on a clone with no brew
 * formulae in it.
 */

#include <stdio.h>
#include <discid/discid.h>

struct toc {
    const char *name;
    int first;
    int last;
    int leadout;
    int offsets[99];
};

/* Offsets are sector addresses as the TOC carries them — the 150-frame pre-gap
 * is already in them, which is why track one is 150 and not 0. */
static const struct toc TOCS[] = {
    { "libdiscid", 1, 7, 164900,
      { 150, 22460, 50197, 80614, 100828, 133318, 144712 } },
    { "fifteen", 1, 15, 258725,
      { 150, 16157, 35932, 54282, 66780, 78952, 97355, 109043,
        122055, 140748, 157068, 175871, 194997, 213504, 244090 } },
    { "single", 1, 1, 180150, { 150 } },
};

/* The disc that is actually in the drive. §19. */
static int read_drive(const char *device) {
    DiscId *d = discid_new();

    if (!discid_read_sparse(d, device, 0)) {
        fprintf(stderr, "%s\n", discid_get_error_msg(d));
        discid_free(d);
        return 1;
    }

    printf("device     %s\n", device ? device : discid_get_default_device());
    printf("id         %s\n", discid_get_id(d));
    printf("toc        %s\n", discid_get_toc_string(d));
    printf("submit     %s\n", discid_get_submission_url(d));
    discid_free(d);
    return 0;
}

int main(int argc, char **argv) {
    if (argc > 1 && argv[1][0] == 'r') {
        return read_drive(argc > 2 ? argv[2] : NULL);
    }

    for (unsigned t = 0; t < sizeof(TOCS) / sizeof(TOCS[0]); t++) {
        const struct toc *toc = &TOCS[t];
        DiscId *d = discid_new();
        int offsets[100] = { 0 };

        /* discid_put wants the lead-out in slot 0 and the tracks after it. */
        offsets[0] = toc->leadout;
        for (int i = 0; i < toc->last - toc->first + 1; i++) {
            offsets[toc->first + i] = toc->offsets[i];
        }

        if (!discid_put(d, toc->first, toc->last, offsets)) {
            fprintf(stderr, "%s: %s\n", toc->name, discid_get_error_msg(d));
            discid_free(d);
            return 1;
        }

        printf("%-10s %s\n", toc->name, discid_get_id(d));
        printf("%-10s toc: %s\n", "", discid_get_toc_string(d));
        discid_free(d);
    }
    return 0;
}
