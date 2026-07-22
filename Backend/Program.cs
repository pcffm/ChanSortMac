// Copyright (C) 2026 Thomas Meroth, Meroth IT-Service
// SPDX-License-Identifier: GPL-3.0-only

using System.Reflection;
using System.Text;
using System.Text.Json;
using ChanSort.Api;

namespace ChanSort.Backend;

internal static class Program
{
  private static readonly JsonSerializerOptions JsonOptions = new()
  {
    PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    WriteIndented = true
  };

  public static int Main(string[] args)
  {
    Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
    ConfigureHeadlessView();

    try
    {
      if (args.Length == 0 || args[0] is "--help" or "-h")
      {
        Console.Error.WriteLine("ChanSort.Backend probe <senderlist-file>");
        return 0;
      }

      return args[0] switch
      {
        "probe" when args.Length == 2 => Probe(Path.GetFullPath(args[1])),
        "save" when args.Length == 2 => Save(Path.GetFullPath(args[1])),
        "plugins" => ListPlugins(),
        _ => throw new ArgumentException("Unknown or incomplete command")
      };
    }
    catch (Exception ex)
    {
      Console.WriteLine(JsonSerializer.Serialize(new ErrorResponse(ex.Message, ex.GetType().Name), JsonOptions));
      return 1;
    }
  }

  private static int Save(string requestFile)
  {
    var request = JsonSerializer.Deserialize<SaveRequest>(File.ReadAllText(requestFile), JsonOptions)
                  ?? throw new InvalidDataException("Invalid save request");
    var sourceFile = Path.GetFullPath(request.SourceFile);
    var outputFile = Path.GetFullPath(string.IsNullOrWhiteSpace(request.OutputFile) ? request.SourceFile : request.OutputFile);
    var plugin = GetPluginsForFile(sourceFile).FirstOrDefault(item => item.GetType().FullName == request.Plugin)
                 ?? throw new InvalidDataException("The requested ChanSort loader is not available");
    using var serializer = plugin.CreateSerializer(sourceFile)
                           ?? throw new InvalidDataException("The requested loader rejected the channel list");
    serializer.Load();
    serializer.DataRoot.ValidateAfterLoad();
    serializer.DataRoot.ApplyCurrentProgramNumbers();

    if (!string.Equals(sourceFile, outputFile, StringComparison.Ordinal))
    {
      if (!serializer.Features.CanSaveAs)
        throw new InvalidOperationException("This proprietary format must be saved over a copy of the complete TV export");
      serializer.SaveAsFileName = outputFile;
    }

    var edits = request.Channels.ToDictionary(edit => edit.Id, StringComparer.Ordinal);
    foreach (var (list, listIndex) in serializer.DataRoot.ChannelLists.Select((value, index) => (value, index)))
    {
      foreach (var (channel, channelIndex) in list.Channels.Select((value, index) => (value, index)))
      {
        var id = $"{listIndex}:{channelIndex}:{channel.RecordIndex}";
        if (!edits.TryGetValue(id, out var edit))
          continue;
        if (channel.Name != edit.Name)
        {
          channel.Name = edit.Name ?? "";
          channel.IsNameModified = true;
        }
        channel.NewProgramNr = edit.ProgramNumber;
        channel.IsDeleted = edit.Deleted;
        channel.Hidden = edit.Hidden;
        channel.Skip = edit.Skipped;
        channel.Lock = edit.Locked;
        channel.Favorites = (Favorites) edit.Favorites;
      }
    }

    if (!serializer.Features.CanHaveGaps)
    {
      foreach (var list in serializer.DataRoot.ChannelLists.Where(list => !list.IsMixedSourceFavoritesList))
      {
        var number = list.FirstProgramNumber;
        foreach (var channel in list.Channels.Where(channel => !channel.IsDeleted && channel.NewProgramNr >= 0).OrderBy(channel => channel.NewProgramNr))
          channel.NewProgramNr = number++;
      }
    }
    serializer.DataRoot.AssignNumbersToUnsortedAndDeletedChannels(UnsortedChannelMode.AppendInOrder);
    if (serializer.Features.EnforceTvBeforeRadioBeforeData)
    {
      foreach (var list in serializer.DataRoot.ChannelLists)
        new Editor { DataRoot = serializer.DataRoot, ChannelList = list, SubListIndex = 0 }.EnforceTvBeforeRadioBeforeData();
    }
    serializer.Save();
    serializer.DataRoot.ValidateAfterSave();

    Console.WriteLine(JsonSerializer.Serialize(new SaveResponse(outputFile, request.Channels.Count), JsonOptions));
    return 0;
  }

  private static int Probe(string fileName)
  {
    if (!File.Exists(fileName))
      throw new FileNotFoundException("Channel list not found", fileName);

    var failures = new List<string>();
    foreach (var plugin in GetPluginsForFile(fileName))
    {
      SerializerBase serializer = null;
      try
      {
        serializer = plugin.CreateSerializer(fileName);
        if (serializer == null)
          continue;
        serializer.Load();
        serializer.DataRoot.ValidateAfterLoad();
        serializer.DataRoot.ApplyCurrentProgramNumbers();

        var lists = serializer.DataRoot.ChannelLists.Select((list, listIndex) => new ListResponse(
          listIndex,
          list.ShortCaption,
          (long) list.SignalSource,
          list.ReadOnly,
          list.Channels.Select((channel, channelIndex) => new ChannelResponse(
            $"{listIndex}:{channelIndex}:{channel.RecordIndex}",
            channel.OldProgramNr,
            channel.NewProgramNr,
            channel.Name,
            channel.ShortName,
            channel.Provider,
            channel.Source,
            channel.Satellite,
            channel.FreqInMhz,
            channel.SymbolRate,
            channel.ServiceId,
            channel.ServiceType,
            channel.IsDeleted,
            channel.Hidden,
            channel.Skip,
            channel.Lock,
            (long) channel.Favorites,
            channel.RecordIndex,
            channel.RecordOrder,
            channel.Uid
          )).ToList()
        )).ToList();

        var response = new ProbeResponse(
          plugin.PluginName,
          plugin.GetType().FullName ?? plugin.GetType().Name,
          serializer.GetType().FullName ?? serializer.GetType().Name,
          serializer.TvModelName,
          serializer.FileFormatVersion,
          serializer.GetFileInformation(),
          serializer.DataRoot.Warnings.ToString(),
          new FeatureResponse(
            serializer.Features.ChannelNameEdit.ToString(),
            serializer.Features.DeleteMode.ToString(),
            serializer.Features.CanSaveAs,
            serializer.Features.CanSkipChannels,
            serializer.Features.CanLockChannels,
            serializer.Features.CanHideChannels,
            serializer.Features.FavoritesMode.ToString(),
            serializer.Features.MaxFavoriteLists
          ),
          lists
        );
        Console.WriteLine(JsonSerializer.Serialize(response, JsonOptions));
        serializer.Dispose();
        return 0;
      }
      catch (Exception ex)
      {
        serializer?.Dispose();
        if (ex.Message != SerializerBase.ERR_UnknownFormat)
          failures.Add($"{plugin.PluginName}: {ex.Message}");
      }
    }

    throw new InvalidDataException(failures.Count == 0
      ? "No ChanSort loader recognized this file"
      : "No loader accepted the file. " + string.Join(" | ", failures));
  }

  private static int ListPlugins()
  {
    var plugins = GetPlugins().Select(plugin => new
    {
      plugin.PluginName,
      plugin.FileFilter,
      Type = plugin.GetType().FullName
    });
    Console.WriteLine(JsonSerializer.Serialize(plugins, JsonOptions));
    return 0;
  }

  private static List<ISerializerPlugin> GetPlugins()
  {
    var assemblies = new List<Assembly> { typeof(ISerializerPlugin).Assembly };
    foreach (var file in Directory.GetFiles(AppContext.BaseDirectory, "ChanSort.Loader.*.dll"))
    {
      try { assemblies.Add(Assembly.LoadFrom(file)); }
      catch { /* A single optional loader must not disable all other formats. */ }
    }

    return assemblies
      .SelectMany(assembly =>
      {
        try { return assembly.GetTypes(); }
        catch (ReflectionTypeLoadException ex) { return ex.Types.Where(type => type != null); }
      })
      .Where(type => type != null && !type.IsAbstract && typeof(ISerializerPlugin).IsAssignableFrom(type))
      .DistinctBy(type => type.FullName)
      .Select(type =>
      {
        try
        {
          var plugin = Activator.CreateInstance(type) as ISerializerPlugin;
          if (plugin != null)
            plugin.DllName = type.Assembly.Location;
          return plugin;
        }
        catch { return null; }
      })
      .Where(plugin => plugin != null)
      .OrderBy(plugin => plugin.FileFilter == "*" ? 1 : 0)
      .ThenBy(plugin => plugin.PluginName)
      .ToList();
  }

  private static IEnumerable<ISerializerPlugin> GetPluginsForFile(string fileName)
  {
    var name = Path.GetFileName(fileName);
    var plugins = GetPlugins();
    var matching = plugins.Where(plugin => plugin.FileFilter.Split(';').Any(pattern => WildcardMatch(name, pattern))).ToList();
    if (name.StartsWith("userbouquet.", StringComparison.OrdinalIgnoreCase))
      matching.InsertRange(0, plugins.Where(plugin => plugin.GetType().FullName == "ChanSort.Loader.Enigma2.Enigma2Plugin" && !matching.Contains(plugin)));
    if (matching.Count == 0)
      matching.AddRange(plugins.Where(plugin => plugin.FileFilter != "*" && plugin.GetType().FullName != "ChanSort.Api.RefSerializerPlugin"));
    return matching.Concat(plugins.Where(plugin => plugin.FileFilter == "*"));
  }

  private static bool WildcardMatch(string value, string pattern)
  {
    var expression = "^" + System.Text.RegularExpressions.Regex.Escape(pattern)
      .Replace("\\*", ".*")
      .Replace("\\?", ".") + "$";
    return System.Text.RegularExpressions.Regex.IsMatch(value, expression,
      System.Text.RegularExpressions.RegexOptions.IgnoreCase | System.Text.RegularExpressions.RegexOptions.CultureInvariant);
  }

  private static void ConfigureHeadlessView()
  {
    View.Default = new View
    {
      MessageBoxImpl = (_, _, buttons, _) => buttons switch
      {
        View.MessageBoxButtons.YesNo or View.MessageBoxButtons.YesNoCancel => View.DialogResult.No,
        View.MessageBoxButtons.OKCancel => View.DialogResult.OK,
        _ => View.DialogResult.OK
      },
      CreateActionBox = _ => new HeadlessActionBox(),
      ShowHtmlBoxImpl = (_, _, _, _, _) => { }
    };
  }

  private sealed class HeadlessActionBox : IActionBoxDialog
  {
    private readonly List<int> actions = [];
    public string Message { get; set; }
    public int SelectedAction { get; private set; }
    public void AddAction(string text, int result) { actions.Add(result); if (actions.Count == 1) SelectedAction = result; }
    public void ShowDialog() { }
    public void Dispose() { }
  }

  private sealed record ErrorResponse(string Error, string Type);
  private sealed record ProbeResponse(string Plugin, string PluginType, string Serializer, string TvModel, string FormatVersion,
    string Information, string Warnings, FeatureResponse Features, List<ListResponse> Lists);
  private sealed record FeatureResponse(string ChannelNameEdit, string DeleteMode, bool CanSaveAs,
    bool CanSkip, bool CanLock, bool CanHide, string FavoritesMode, int MaxFavoriteLists);
  private sealed record ListResponse(int Id, string Name, long SignalSource, bool ReadOnly, List<ChannelResponse> Channels);
  private sealed record ChannelResponse(string Id, int OldProgramNumber, int ProgramNumber, string Name,
    string ShortName, string Provider, string Source, string Satellite, decimal FrequencyMhz, int SymbolRate,
    int ServiceId, int ServiceType, bool Deleted, bool Hidden, bool Skipped, bool Locked, long Favorites,
    long RecordIndex, int RecordOrder, string Uid);
  private sealed record SaveRequest(string SourceFile, string OutputFile, string Plugin, List<ChannelEdit> Channels);
  private sealed record ChannelEdit(string Id, int ProgramNumber, string Name, bool Deleted, bool Hidden,
    bool Skipped, bool Locked, long Favorites);
  private sealed record SaveResponse(string File, int UpdatedChannels);
}
