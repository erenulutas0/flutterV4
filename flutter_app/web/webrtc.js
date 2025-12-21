// WebRTC helper functions for Flutter web
class WebRTCManager {
  constructor(roomId, role = 'callee') {
    // Socket'i window'dan al (Flutter'dan geçirilen)
    this.socket = window.currentSocket;
    this.roomId = roomId;
    this.role = role; // 'caller' or 'callee'
    
    if (!this.socket) {
      console.error('Socket not found! Make sure socket is set in window.currentSocket');
      throw new Error('Socket bağlantısı bulunamadı');
    }
    this.localStream = null;
    this.peerConnection = null;
    this.localVideoElement = null;
    this.remoteVideoElement = null;
    this.isVideoEnabled = true;
    this.isAudioEnabled = true;
    this.iceCandidateQueue = []; // Remote description set edilene kadar ICE candidate'ları tut
    this.audioContext = null; // Ses kontrolü için AudioContext
    this.localGainNode = null; // Local audio gain kontrolü
    this.initializationPromise = null; // Initialize promise'ini sakla
    console.log('WebRTCManager created with role:', this.role);
  }

  async initialize(role) {
    // Eğer zaten initialize ediliyorsa, mevcut promise'i döndür
    if (this.initializationPromise) {
      console.log('Initialization already in progress, waiting for existing promise...');
      return await this.initializationPromise;
    }
    
    // Role parametresini güncelle (eğer verilmişse)
    if (role) {
      this.role = role;
      console.log('Role updated to:', this.role);
    }
    
    // Initialize promise'ini oluştur ve sakla
    this.initializationPromise = (async () => {
      try {
        // Check if mediaDevices is available
        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
          throw new Error('Tarayıcınız kamera/mikrofon erişimini desteklemiyor');
        }

        // Get user media with better error handling
        // Önce daha düşük kalite ile dene (aynı cihazda iki tarayıcı için)
        try {
          this.localStream = await navigator.mediaDevices.getUserMedia({
            video: {
              width: { ideal: 640, max: 1280 },
              height: { ideal: 480, max: 720 },
              facingMode: 'user'
            },
            audio: {
              echoCancellation: true,
              noiseSuppression: true
            }
          });
        } catch (mediaError) {
          let errorMessage = 'Kamera/mikrofon erişimi hatası: ';
          if (mediaError.name === 'NotAllowedError' || mediaError.name === 'PermissionDeniedError') {
            errorMessage += 'Lütfen tarayıcı ayarlarından kamera ve mikrofon izni verin';
          } else if (mediaError.name === 'NotFoundError' || mediaError.name === 'DevicesNotFoundError') {
            errorMessage += 'Kamera veya mikrofon bulunamadı. Lütfen cihazınızı kontrol edin';
          } else if (mediaError.name === 'NotReadableError' || mediaError.name === 'TrackStartError') {
            errorMessage += 'Kamera başka bir uygulama tarafından kullanılıyor olabilir. Lütfen diğer uygulamaları kapatın';
          } else if (mediaError.name === 'OverconstrainedError' || mediaError.name === 'ConstraintNotSatisfiedError') {
            errorMessage += 'Kamera ayarları desteklenmiyor. Daha düşük kalite denenecek...';
            // Try with lower constraints
            try {
              this.localStream = await navigator.mediaDevices.getUserMedia({
                video: true,
                audio: true
              });
            } catch (retryError) {
              throw new Error(errorMessage);
            }
          } else {
            errorMessage += mediaError.message || 'Bilinmeyen hata';
          }
          throw new Error(errorMessage);
        }

        // Setup local video
        this.setupLocalVideo();

        // Create peer connection
        this.peerConnection = new RTCPeerConnection({
          iceServers: [
            { urls: 'stun:stun.l.google.com:19302' },
            { urls: 'stun:stun1.l.google.com:19302' }
          ]
        });

        // Add local stream tracks
        this.localStream.getTracks().forEach(track => {
          this.peerConnection.addTrack(track, this.localStream);
        });

        // ICE candidate handler
        this.peerConnection.onicecandidate = (event) => {
          if (event.candidate && this.socket && typeof this.socket.emit === 'function') {
            this.socket.emit('webrtc_ice_candidate', {
              roomId: this.roomId,
              candidate: {
                candidate: event.candidate.candidate,
                sdpMLineIndex: event.candidate.sdpMLineIndex,
                sdpMid: event.candidate.sdpMid
              }
            });
          }
        };

        // Connection state handler
        this.peerConnection.onconnectionstatechange = () => {
          try {
            const state = this.peerConnection.connectionState;
            window.dispatchEvent(new CustomEvent('webrtc_connection_state', { detail: state }));
          } catch (error) {
            console.error('Error in connection state change handler:', error);
          }
        };

        // Remote stream handler
        this.peerConnection.ontrack = (event) => {
          if (event.streams && event.streams.length > 0) {
            this.setupRemoteVideo(event.streams[0]);
          }
        };

        // Role'e göre offer oluştur
        // Sadece 'caller' role'üne sahip olan offer oluşturur
        // 'callee' sadece bekler ve offer geldiğinde answer oluşturur
        if (this.role === 'caller') {
          console.log('✅ I am the CALLER, creating offer...');
          // Caller ise hemen offer oluştur
          setTimeout(() => {
            this.createOffer();
          }, 100); // Kısa bir delay ile offer oluştur (socket bağlantısının hazır olması için)
        } else {
          console.log('⏳ I am the CALLEE, waiting for offer...');
          // Callee ise sadece bekler, offer geldiğinde handleOffer çağrılacak
        }

        return true;
      } catch (error) {
        console.error('WebRTC initialization error:', error);
        // Dispatch error event to Flutter
        window.dispatchEvent(new CustomEvent('webrtc_error', { 
          detail: error.message || error.toString() 
        }));
        throw error; // Re-throw to let caller handle
      }
    })();
    
    try {
      const result = await this.initializationPromise;
      return result;
    } finally {
      // Initialize tamamlandıktan sonra promise'i temizle
      this.initializationPromise = null;
    }
  }

  setupLocalVideo() {
    // Create container if it doesn't exist
    let container = document.getElementById('localVideoContainer');
    if (!container) {
      container = document.createElement('div');
      container.id = 'localVideoContainer';
      container.style.position = 'fixed';
      container.style.top = '20px';
      container.style.right = '20px';
      container.style.width = '120px';
      container.style.height = '160px';
      container.style.borderRadius = '8px';
      container.style.overflow = 'hidden';
      container.style.border = '2px solid white';
      container.style.zIndex = '10001'; // En üstte olmalı (remote video'dan yukarıda)
      container.style.pointerEvents = 'auto'; // Tıklamaları al
      container.style.backgroundColor = '#000';
      document.body.appendChild(container);
      console.log('Created local video container with z-index 10000');
    }

    this.localVideoElement = document.createElement('video');
    this.localVideoElement.autoplay = true;
    this.localVideoElement.muted = true;
    this.localVideoElement.style.width = '100%';
    this.localVideoElement.style.height = '100%';
    this.localVideoElement.style.objectFit = 'cover';
    this.localVideoElement.srcObject = this.localStream;
    container.appendChild(this.localVideoElement);
  }

  setupRemoteVideo(stream) {
    // Create container if it doesn't exist
    let container = document.getElementById('remoteVideoContainer');
    if (!container) {
      container = document.createElement('div');
      container.id = 'remoteVideoContainer';
      container.style.position = 'fixed';
      container.style.top = '0';
      container.style.left = '0';
      container.style.width = '100vw';
      container.style.height = '100vh';
      container.style.zIndex = '0'; // Flutter Stack'in altında (kontroller görünsün)
      container.style.backgroundColor = '#000';
      container.style.pointerEvents = 'none'; // Tıklamaları geçir
      // Body'ye ekle (Flutter Stack ile aynı seviyede)
      document.body.appendChild(container);
      console.log('✅ Created remote video container with z-index 0 (below Flutter Stack, controls visible) - v15 - FIX');
      
      // Flutter Stack'in z-index'ini artır (kontrollerin görünmesi için)
      setTimeout(() => {
        const flutterHost = document.querySelector('flt-scene-host');
        if (flutterHost) {
          flutterHost.style.zIndex = '10000';
          flutterHost.style.position = 'relative';
          console.log('✅ Flutter Stack z-index set to 10000');
        }
      }, 100);
    } else {
      // Container zaten varsa, z-index'i güncelle (eski versiyon olabilir)
      container.style.zIndex = '9999';
        container.style.zIndex = '0'; // Güncelle
        console.log('✅ Updated existing remote video container z-index to 0');
    }

    // Eğer video element zaten varsa, sadece stream'i güncelle
    const isNewElement = !this.remoteVideoElement;
    if (this.remoteVideoElement) {
      console.log('Updating existing remote video element with new stream');
      this.remoteVideoElement.srcObject = stream;
    } else {
      console.log('Creating new remote video element');
      this.remoteVideoElement = document.createElement('video');
      this.remoteVideoElement.autoplay = true;
      this.remoteVideoElement.playsInline = true;
      this.remoteVideoElement.muted = false; // Remote video sesli olmalı
      this.remoteVideoElement.style.width = '100%';
      this.remoteVideoElement.style.height = '100%';
      this.remoteVideoElement.style.objectFit = 'contain'; // Video'yu container'a sığdır, kesme
      this.remoteVideoElement.style.backgroundColor = '#000';
      this.remoteVideoElement.style.display = 'block'; // Görünür olmalı
      this.remoteVideoElement.style.opacity = '1'; // Tamamen görünür
      this.remoteVideoElement.style.visibility = 'visible'; // Görünür
      this.remoteVideoElement.style.position = 'relative'; // Position set et
      this.remoteVideoElement.style.zIndex = '1'; // Container'ın içinde z-index
      this.remoteVideoElement.srcObject = stream;
      
      // Stream'in aktif olduğunu kontrol et
      console.log('Remote video stream tracks:', stream.getTracks());
      stream.getTracks().forEach(track => {
        console.log('Track:', track.kind, 'enabled:', track.enabled, 'readyState:', track.readyState);
        track.onended = () => console.log('Track ended:', track.kind);
      });
      
      container.innerHTML = ''; // Önceki içeriği temizle
      container.appendChild(this.remoteVideoElement);
      
      // Video element'in gerçekten stream aldığını doğrula
      console.log('Remote video element srcObject:', this.remoteVideoElement.srcObject);
      console.log('Remote video element readyState:', this.remoteVideoElement.readyState);
      
      // Video element'in görünür olduğundan emin ol
      this.remoteVideoElement.style.opacity = '1';
      this.remoteVideoElement.style.visibility = 'visible';
      this.remoteVideoElement.style.display = 'block';
      this.remoteVideoElement.style.position = 'relative';
      this.remoteVideoElement.style.zIndex = '1';
      
      // Video yüklendikten sonra oynat - daha agresif retry (readyState >= 0 olsa bile dene)
      let playAttempts = 0;
      const maxPlayAttempts = 20; // Maksimum 20 deneme
      const tryPlay = () => {
        if (!this.remoteVideoElement) return;
        if (playAttempts >= maxPlayAttempts) {
          console.warn('Max play attempts reached, giving up');
          return;
        }
        playAttempts++;
        
        // Video element'in görünür olduğundan emin ol (her denemede)
        this.remoteVideoElement.style.opacity = '1';
        this.remoteVideoElement.style.visibility = 'visible';
        this.remoteVideoElement.style.display = 'block';
        this.remoteVideoElement.style.width = '100%';
        this.remoteVideoElement.style.height = '100%';
        
        // readyState >= 0 olsa bile dene (HAVE_NOTHING bile olsa)
        this.remoteVideoElement.play().then(() => {
          console.log('Remote video play() successful, readyState:', this.remoteVideoElement.readyState, 'attempt:', playAttempts);
        }).catch(err => {
          console.warn('Remote video play() failed (will retry):', err, 'readyState:', this.remoteVideoElement.readyState, 'attempt:', playAttempts);
          // 200ms sonra tekrar dene
          setTimeout(tryPlay, 200);
        });
      };
      
      // İlk denemeyi hemen yap
      setTimeout(tryPlay, 100);
    }
    
    // Event'i hemen dispatch et - video element oluşturuldu ve stream atandı
    // Her zaman dispatch et, çünkü stream güncellenmiş olabilir
    console.log('Dispatching webrtc_remote_video_ready event immediately (isNewElement: ' + isNewElement + ')');
    window.dispatchEvent(new CustomEvent('webrtc_remote_video_ready', { detail: 'setup' }));
    
    // Video yüklendiğinde event dispatch et
    this.remoteVideoElement.onloadedmetadata = () => {
      console.log('Remote video metadata loaded, readyState:', this.remoteVideoElement.readyState);
      // Metadata yüklendiğinde play() dene
      this.remoteVideoElement.play().then(() => {
        console.log('Remote video play() successful (onloadedmetadata)');
      }).catch(err => {
        console.warn('Remote video play() failed on loadedmetadata:', err);
        // Retry after a short delay
        setTimeout(() => this.remoteVideoElement.play().catch(e => console.warn('Retry play() failed:', e)), 200);
      });
    };
    
    // Video data yüklendiğinde event dispatch et
    this.remoteVideoElement.onloadeddata = () => {
      console.log('Remote video data loaded, readyState:', this.remoteVideoElement.readyState);
      // Data yüklendiğinde play() dene
      this.remoteVideoElement.play().then(() => {
        console.log('Remote video play() successful (onloadeddata)');
      }).catch(err => {
        console.warn('Remote video play() failed on loadeddata:', err);
        // Retry after a short delay
        setTimeout(() => this.remoteVideoElement.play().catch(e => console.warn('Retry play() failed:', e)), 200);
      });
      window.dispatchEvent(new CustomEvent('webrtc_remote_video_ready', { detail: 'loaded' }));
    };
    
    // Video oynatıldığında event dispatch et
    this.remoteVideoElement.onplay = () => {
      console.log('Remote video started playing');
      window.dispatchEvent(new CustomEvent('webrtc_remote_video_ready', { detail: 'playing' }));
    };
    
    // Video oynatma hatası
    this.remoteVideoElement.onerror = (error) => {
      console.error('Remote video error:', error);
    };
    
    // Video canplay event - video oynatılmaya hazır
    this.remoteVideoElement.oncanplay = () => {
      console.log('Remote video can play, readyState:', this.remoteVideoElement.readyState);
      this.remoteVideoElement.play().catch(err => {
        console.warn('Remote video play() failed on canplay:', err);
      });
    };
    
    // Eğer video zaten oynatılıyorsa, hemen event dispatch et
    if (this.remoteVideoElement.readyState >= 2) {
      console.log('Remote video already has data, dispatching event immediately');
      this.remoteVideoElement.play().then(() => {
        console.log('Remote video play() successful (readyState check)');
      }).catch(err => {
        console.warn('Remote video play() failed on readyState check:', err);
      });
      window.dispatchEvent(new CustomEvent('webrtc_remote_video_ready', { detail: 'ready' }));
    }
    
    console.log('Remote video setup complete');
  }

  async createOffer() {
    try {
      const offer = await this.peerConnection.createOffer({
        offerToReceiveAudio: true,
        offerToReceiveVideo: true
      });

      await this.peerConnection.setLocalDescription(offer);

      if (this.socket && typeof this.socket.emit === 'function') {
        this.socket.emit('webrtc_offer', {
          roomId: this.roomId,
          offer: {
            type: offer.type,
            sdp: offer.sdp
          }
        });
        console.log('Offer created and sent');
      } else {
        console.error('Socket emit is not available');
      }
    } catch (error) {
      console.error('Error creating offer:', error);
    }
  }

      async handleOffer(offerData) {
        console.log('📥 Offer received, role:', this.role);
        // Callee olmalıyız, çünkü caller offer oluşturur
        if (this.role === 'caller') {
          console.warn('⚠️ Warning: Caller received an offer, this should not happen');
          console.warn('   This might be a duplicate offer, ignoring...');
          return;
        }
        try {
          // Peer connection kontrolü - eğer yoksa initialize et
          if (!this.peerConnection) {
            console.warn('⚠️ Peer connection is null, initializing now...');
            // Local stream hazır mı kontrol et
            if (!this.localStream) {
              console.log('⏳ Local stream is not ready, waiting for initialization...');
              // getUserMedia henüz tamamlanmamış, initialize promise'ini bekle
              try {
                await this.initialize(this.role);
                console.log('✅ Initialization completed, peer connection should be ready now');
              } catch (initError) {
                console.error('❌ Failed to initialize:', initError);
                return;
              }
            } else {
              // Local stream var ama peer connection yok, sadece peer connection oluştur
              this.peerConnection = new RTCPeerConnection({
                iceServers: [
                  { urls: 'stun:stun.l.google.com:19302' },
                  { urls: 'stun:stun1.l.google.com:19302' }
                ]
              });
              // Add local stream tracks
              this.localStream.getTracks().forEach(track => {
                this.peerConnection.addTrack(track, this.localStream);
              });
              // Re-add event handlers
              this.peerConnection.onicecandidate = (event) => {
                if (event.candidate && this.socket && typeof this.socket.emit === 'function') {
                  this.socket.emit('webrtc_ice_candidate', {
                    roomId: this.roomId,
                    candidate: {
                      candidate: event.candidate.candidate,
                      sdpMLineIndex: event.candidate.sdpMLineIndex,
                      sdpMid: event.candidate.sdpMid
                    }
                  });
                }
              };
              this.peerConnection.onconnectionstatechange = () => {
                try {
                  const state = this.peerConnection.connectionState;
                  window.dispatchEvent(new CustomEvent('webrtc_connection_state', { detail: state }));
                } catch (error) {
                  console.error('Error in connection state change handler:', error);
                }
              };
              this.peerConnection.ontrack = (event) => {
                if (event.streams && event.streams.length > 0) {
                  this.setupRemoteVideo(event.streams[0]);
                }
              };
            }
            if (!this.peerConnection) {
              console.error('❌ Peer connection is still null after initialization');
              return;
            }
          }
      
      // Eğer zaten bir remote description set edilmişse, yeni bir offer'ı ignore et
      if (this.peerConnection.remoteDescription && this.peerConnection.remoteDescription.type === 'offer') {
        console.log('Offer already set, ignoring duplicate offer');
        return;
      }

      // Eğer local description zaten set edilmişse (yani biz offer oluşturduk)
      // WebRTC'de local description offer iken remote description set edilemez
      // Bu durumda, peer connection'ı yeniden oluşturmalıyız
      if (this.peerConnection.localDescription && this.peerConnection.localDescription.type === 'offer') {
        if (this.peerConnection.remoteDescription) {
          // Zaten bir remote description var, yeni offer'ı ignore et
          console.log('We are the offerer and already have remote description, ignoring incoming offer');
          return;
        } else {
          // Çakışma durumu: Her iki taraf da offer oluşturmuş
          // Peer connection'ı yeniden oluştur ve gelen offer'ı kabul et
          console.log('Offer collision detected, recreating peer connection to accept incoming offer');
          
          // Mevcut peer connection'ı kapat ve temizle
          if (this.peerConnection) {
            this.peerConnection.close();
          }
          
          // ICE candidate queue'yu temizle
          this.iceCandidateQueue = [];
          
          // Yeni peer connection oluştur
          this.peerConnection = new RTCPeerConnection({
            iceServers: [
              { urls: 'stun:stun.l.google.com:19302' },
              { urls: 'stun:stun1.l.google.com:19302' }
            ]
          });
          
          // Local stream'i yeni peer connection'a ekle
          this.localStream.getTracks().forEach(track => {
            this.peerConnection.addTrack(track, this.localStream);
          });
          
          // Event handler'ları yeniden ekle
          this.peerConnection.onicecandidate = (event) => {
            if (event.candidate && this.socket && typeof this.socket.emit === 'function') {
              this.socket.emit('webrtc_ice_candidate', {
                roomId: this.roomId,
                candidate: {
                  candidate: event.candidate.candidate,
                  sdpMLineIndex: event.candidate.sdpMLineIndex,
                  sdpMid: event.candidate.sdpMid
                }
              });
            }
          };
          
          this.peerConnection.onconnectionstatechange = () => {
            try {
              const state = this.peerConnection.connectionState;
              window.dispatchEvent(new CustomEvent('webrtc_connection_state', { detail: state }));
            } catch (error) {
              console.error('Error in connection state change handler:', error);
            }
          };
          
          this.peerConnection.ontrack = (event) => {
            if (event.streams && event.streams.length > 0) {
              this.setupRemoteVideo(event.streams[0]);
            }
          };
          
          // Şimdi gelen offer'ı işle - devam ediyoruz
          // Aşağıdaki kod offer'ı set edecek
        }
      }

      // Eğer buraya geldiysek, offer'ı set etmeye hazırız
      // Peer connection'ın state'ini kontrol et
      console.log('About to set remote description. Current state:', this.peerConnection.connectionState);
      console.log('Current local description:', this.peerConnection.localDescription?.type);
      console.log('Current remote description:', this.peerConnection.remoteDescription?.type);

      const offer = new RTCSessionDescription({
        type: offerData.type,
        sdp: offerData.sdp
      });

      try {
        await this.peerConnection.setRemoteDescription(offer);
        console.log('✅ Remote description (offer) set successfully');
        console.log('   Connection state:', this.peerConnection.connectionState);
        console.log('   Remote description type:', this.peerConnection.remoteDescription?.type);
        console.log('   Local description type:', this.peerConnection.localDescription?.type);
        
        // Remote description set edildi, queue'daki ICE candidate'ları ekle
        await this.processIceCandidateQueue();
      } catch (error) {
        console.error('Error setting remote description:', error);
        console.error('Current peer connection state:', this.peerConnection?.connectionState);
        console.error('Current local description:', this.peerConnection?.localDescription?.type);
        console.error('Current remote description:', this.peerConnection?.remoteDescription?.type);
        throw error; // Re-throw to let caller handle
      }

      // Answer oluşturmadan önce state kontrolü
      console.log('About to create answer. Current state:', this.peerConnection.connectionState);
      console.log('Remote description:', this.peerConnection.remoteDescription?.type);
      console.log('Local description:', this.peerConnection.localDescription?.type);
      
      if (!this.peerConnection.remoteDescription || this.peerConnection.remoteDescription.type !== 'offer') {
        console.error('❌ Cannot create answer: remote description is not an offer');
        console.error('   Remote description:', this.peerConnection.remoteDescription?.type);
        console.error('   Connection state:', this.peerConnection.connectionState);
        throw new Error('Remote description must be an offer before creating answer');
      }

      const answer = await this.peerConnection.createAnswer();
      
      // setLocalDescription çağrılmadan önce state kontrolü
      console.log('About to set local description (answer). Current state:', this.peerConnection.connectionState);
      console.log('Remote description:', this.peerConnection.remoteDescription?.type);
      console.log('Local description (before):', this.peerConnection.localDescription?.type);
      
      if (this.peerConnection.localDescription) {
        console.warn('⚠️ Local description already set:', this.peerConnection.localDescription.type);
        console.warn('   This might cause an error. Skipping setLocalDescription.');
        return; // Local description zaten set edilmişse, tekrar set etme
      }
      
      await this.peerConnection.setLocalDescription(answer);
      console.log('✅ Answer created and set successfully');
      console.log('   Connection state:', this.peerConnection.connectionState);
      console.log('   Local description:', this.peerConnection.localDescription?.type);
      console.log('   Remote description:', this.peerConnection.remoteDescription?.type);

      if (this.socket && typeof this.socket.emit === 'function') {
        this.socket.emit('webrtc_answer', {
          roomId: this.roomId,
          answer: {
            type: answer.type,
            sdp: answer.sdp
          }
        });
        console.log('Answer created and sent');
      } else {
        console.error('Socket emit is not available');
      }
    } catch (error) {
      console.error('Error handling offer:', error);
      window.dispatchEvent(new CustomEvent('webrtc_error', { detail: 'Offer işlenirken hata: ' + error.message }));
    }
  }

  async handleAnswer(answerData) {
    try {
      // Peer connection kontrolü - eğer yoksa initialize et
      if (!this.peerConnection) {
        console.warn('Peer connection is null, initializing now...');
        // Local stream hazır mı kontrol et
        if (!this.localStream) {
          console.error('Local stream is not ready, cannot initialize peer connection');
          return;
        }
        const initialized = await this.initialize(this.role);
        if (!initialized) {
          console.error('Failed to initialize peer connection for answer');
          return;
        }
        if (!this.peerConnection) {
          console.error('Peer connection is still null after initialization');
          return;
        }
      }
      
      // Eğer zaten bir remote description set edilmişse ve type answer ise, ignore et
      if (this.peerConnection.remoteDescription && this.peerConnection.remoteDescription.type === 'answer') {
        console.log('Answer already set, ignoring duplicate answer');
        return;
      }

      // Eğer local description offer ise (yani biz offerer'ız), remote answer'ı set et
      if (this.peerConnection.localDescription && this.peerConnection.localDescription.type === 'offer') {
        const answer = new RTCSessionDescription({
          type: answerData.type,
          sdp: answerData.sdp
        });

        try {
          await this.peerConnection.setRemoteDescription(answer);
          console.log('Remote answer set successfully, connection state:', this.peerConnection.connectionState);
          console.log('Remote description type:', this.peerConnection.remoteDescription?.type);
          console.log('Local description type:', this.peerConnection.localDescription?.type);
          
          // Remote description set edildi, queue'daki ICE candidate'ları ekle
          this.processIceCandidateQueue();
        } catch (error) {
          console.error('Error setting remote answer:', error);
          console.error('Current peer connection state:', this.peerConnection?.connectionState);
          console.error('Current local description:', this.peerConnection?.localDescription?.type);
          console.error('Current remote description:', this.peerConnection?.remoteDescription?.type);
          throw error; // Re-throw to let caller handle
        }

        console.log('Answer set successfully');
      } else {
        // Local description yoksa veya offer değilse, bu bir hata durumu olabilir
        // Ama peer connection yeniden oluşturulmuş olabilir, bu durumda answer'ı ignore et
        console.log('Warning: Answer received but we are not the offerer. Local description:', this.peerConnection.localDescription?.type);
        // Answer'ı ignore etme, çünkü peer connection yeniden oluşturulmuş olabilir
      }
    } catch (error) {
      console.error('Error handling answer:', error);
      window.dispatchEvent(new CustomEvent('webrtc_error', { detail: 'Answer işlenirken hata: ' + error.message }));
    }
  }

  async handleIceCandidate(candidateData) {
    try {
      // Peer connection kontrolü - eğer yoksa queue'ya ekle
      if (!this.peerConnection) {
        console.warn('Peer connection is null, queueing ICE candidate for later');
        if (!this.iceCandidateQueue) {
          this.iceCandidateQueue = [];
        }
        const candidate = new RTCIceCandidate({
          candidate: candidateData.candidate,
          sdpMLineIndex: candidateData.sdpMLineIndex,
          sdpMid: candidateData.sdpMid
        });
        this.iceCandidateQueue.push(candidate);
        return;
      }
      
      const candidate = new RTCIceCandidate({
        candidate: candidateData.candidate,
        sdpMLineIndex: candidateData.sdpMLineIndex,
        sdpMid: candidateData.sdpMid
      });
      
      // Eğer remote description henüz set edilmemişse, queue'ya ekle
      if (!this.peerConnection.remoteDescription) {
        if (!this.iceCandidateQueue) {
          this.iceCandidateQueue = [];
        }
        this.iceCandidateQueue.push(candidate);
        console.log('ICE candidate queued (remote description not set yet)');
        return;
      }
      
      // Remote description set edilmişse, direkt ekle
      await this.peerConnection.addIceCandidate(candidate);
    } catch (error) {
      console.error('Error handling ICE candidate:', error);
      window.dispatchEvent(new CustomEvent('webrtc_error', { detail: 'ICE adayı eklenirken hata: ' + error.message }));
    }
  }
  
      async processIceCandidateQueue() {
        if (!this.peerConnection) {
          console.warn('Peer connection is null, cannot process ICE candidate queue');
          return;
        }
        if (!this.iceCandidateQueue || this.iceCandidateQueue.length === 0) {
          return;
        }
        // Remote description set edilmiş mi kontrol et
        if (!this.peerConnection.remoteDescription) {
          console.warn('Remote description not set yet, cannot process ICE candidate queue');
          return;
        }
        // Queue'daki tüm ICE candidate'ları ekle
        const candidatesToProcess = [...this.iceCandidateQueue]; // Copy array
        this.iceCandidateQueue = []; // Clear queue first
        for (const candidate of candidatesToProcess) {
          try {
            // Double check remote description is set
            if (!this.peerConnection.remoteDescription) {
              console.warn('Remote description became null, re-queueing candidate');
              this.iceCandidateQueue.push(candidate);
              continue;
            }
            await this.peerConnection.addIceCandidate(candidate);
            console.log('Queued ICE candidate added');
          } catch (error) {
            console.error('Error adding queued ICE candidate:', error);
            // Don't re-queue if it's an InvalidStateError - the candidate is likely invalid now
            if (error.name !== 'InvalidStateError') {
              this.iceCandidateQueue.push(candidate);
            }
          }
        }
      }

  toggleVideo() {
    if (this.localStream) {
      this.isVideoEnabled = !this.isVideoEnabled;
      this.localStream.getVideoTracks().forEach(track => {
        track.enabled = this.isVideoEnabled;
      });
      return this.isVideoEnabled;
    }
    return false;
  }

  toggleAudio() {
    if (this.localStream) {
      this.isAudioEnabled = !this.isAudioEnabled;
      this.localStream.getAudioTracks().forEach(track => {
        track.enabled = this.isAudioEnabled;
      });
      return this.isAudioEnabled;
    }
    return false;
  }

  setRemoteVolume(volume) {
    // 0.0 - 1.0 arası
    if (this.remoteVideoElement) {
      this.remoteVideoElement.volume = Math.max(0, Math.min(1, volume));
    }
  }

  setLocalVolume(volume) {
    // 0.0 - 1.0 arası
    // Local audio track'lerinin gain'ini ayarla
    try {
      if (!this.audioContext) {
        this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
      }
      
      if (this.localStream) {
        const audioTracks = this.localStream.getAudioTracks();
        if (audioTracks.length > 0 && !this.localGainNode) {
          // AudioContext ile gain node oluştur
          const source = this.audioContext.createMediaStreamSource(this.localStream);
          this.localGainNode = this.audioContext.createGain();
          source.connect(this.localGainNode);
          // Gain node'u destination'a bağla (ama bu local stream'i değiştirmez)
          // WebRTC için daha karmaşık bir yaklaşım gerekir
        }
        
        if (this.localGainNode) {
          this.localGainNode.gain.value = Math.max(0, Math.min(1, volume));
        }
      }
    } catch (error) {
      console.error('Error setting local volume:', error);
      // Fallback: track.enabled ile kontrol (sadece açık/kapalı)
      if (this.localStream) {
        this.localStream.getAudioTracks().forEach(track => {
          track.enabled = volume > 0;
        });
      }
    }
  }

  cleanup() {
    if (this.localStream) {
      this.localStream.getTracks().forEach(track => track.stop());
    }
    if (this.peerConnection) {
      this.peerConnection.close();
    }
    if (this.localVideoElement) {
      this.localVideoElement.remove();
    }
    if (this.remoteVideoElement) {
      this.remoteVideoElement.remove();
    }
    // Remove containers
    const localContainer = document.getElementById('localVideoContainer');
    if (localContainer) localContainer.remove();
    const remoteContainer = document.getElementById('remoteVideoContainer');
    if (remoteContainer) remoteContainer.remove();
  }
}

// Global instance
window.WebRTCManager = WebRTCManager;

