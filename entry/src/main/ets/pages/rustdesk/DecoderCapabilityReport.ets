import { DecoderCapability } from './RustDeskTypes';

/**
 * Reads the engine's decoder capability report into the rows the app shows and
 * decides with.
 *
 * The report is `{ok, h264_decoder, hevc_decoder, ...}`, where each decoder is
 * either `{ok:true, codec_name, mime, hardware, ...}` (what the platform
 * advertises) or `{ok:false, error}`. It names exactly the decoders this
 * engine can open: H.264 and H.265. There is no row for VP8, VP9 or AV1
 * because the engine has no decoder for them on this platform, and a row is
 * never invented for one.
 *
 * "Advertised" is the platform's own metadata, not a measurement: a row says
 * the decoder exists, not how fast it is.
 */
function decoderRow(codec: string, source: ESObject): DecoderCapability | undefined {
  if (source === undefined || source === null || typeof source !== 'object' || source.ok !== true) {
    return undefined;
  }
  const name: string = typeof source.codec_name === 'string' ? (source.codec_name as string).trim() : '';
  const hardware: boolean = source.hardware === true;
  const row = new DecoderCapability();
  row.codec = codec;
  row.mime = typeof source.mime === 'string' ? (source.mime as string).trim() : '';
  row.mimeAvailable = true;
  row.recommendedAvailable = true;
  row.recommendedName = name;
  row.recommendedIsHardware = hardware;
  row.hardwareAvailable = hardware;
  row.hardwareName = hardware ? name : '';
  row.softwareAvailable = !hardware;
  row.softwareName = hardware ? '' : name;
  return row;
}

/** The decoders the report really names, H.265 first. Unreadable input is none. */
export function decoderCapabilitiesFromReport(raw: string): DecoderCapability[] {
  const rows: DecoderCapability[] = [];
  try {
    const report: ESObject = JSON.parse(raw);
    if (report === null || typeof report !== 'object') {
      return rows;
    }
    const hevc = decoderRow('H265', report.hevc_decoder);
    if (hevc !== undefined) {
      rows.push(hevc);
    }
    const h264 = decoderRow('H264', report.h264_decoder);
    if (h264 !== undefined) {
      rows.push(h264);
    }
  } catch (_) {
    // A report that cannot be read names no decoder.
  }
  return rows;
}

/**
 * The codec preference a session asks for.
 *
 * `auto` stays `auto`: the other device chooses among what this device
 * advertised, exactly as before. An explicit choice is kept only when the
 * report names that decoder; anything else falls back to `auto` rather than
 * asking for a codec this device cannot decode.
 */
export function resolveCodecPreference(requested: string, capabilities: DecoderCapability[]): string {
  const wanted = requested.trim().toLowerCase();
  if (wanted !== 'h264' && wanted !== 'h265') {
    return 'auto';
  }
  for (let index = 0; index < capabilities.length; index += 1) {
    if (capabilities[index].codec.toLowerCase() === wanted) {
      return wanted;
    }
  }
  return 'auto';
}
